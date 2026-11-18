"""Compare the linked tokenizer against the model vocabulary for every byte.

No model weights are loaded. Set CACTUS_TOKENIZER_LIBRARY, CACTUS_TOKENIZER_SOURCE,
and CACTUS_EVAL_MODEL_DIR to a reviewed candidate to exercise the native contract.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


@unittest.skipUnless(all(os.environ.get(k) for k in [
    'CACTUS_TOKENIZER_LIBRARY', 'CACTUS_TOKENIZER_SOURCE', 'CACTUS_EVAL_MODEL_DIR'
]), 'Reviewed native tokenizer fixture paths are required')
class ByteLevelMappingTests(unittest.TestCase):
    def test_all_256_bytes_and_hash_merge_match_model_vocabulary(self):
        library = Path(os.environ['CACTUS_TOKENIZER_LIBRARY'])
        source = Path(os.environ['CACTUS_TOKENIZER_SOURCE'])
        model = Path(os.environ['CACTUS_EVAL_MODEL_DIR'])
        visible = list(range(33, 127)) + list(range(161, 173)) + list(range(174, 256))
        byte_points = {byte: byte for byte in visible}
        for index, byte in enumerate(b for b in range(256) if b not in byte_points):
            byte_points[byte] = 256 + index
        vocabulary = json.loads((model / 'tokenizer.json').read_text())['model']['vocab']
        expected = [[vocabulary[chr(byte_points[b])]] for b in range(256)]
        expected.append([vocabulary['##']])
        with tempfile.TemporaryDirectory(prefix='memoryos-token-byte-test-') as directory:
            root = Path(directory)
            cpp = root / 'bytes.cpp'
            cpp.write_text('''#include "engine.h"
#include <iostream>
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::string model = argv[1]; cactus::engine::BPETokenizer tokenizer;
    if (!tokenizer.load_vocabulary_with_config(model+"/vocab.txt", model+"/merges.txt", model+"/tokenizer_config.txt")) return 3;
    std::cout << "[";
    for (int b = 0; b < 256; ++b) {
        auto ids = tokenizer.encode(std::string(1, static_cast<char>(b)));
        if (b) std::cout << ","; std::cout << "[";
        for (size_t i = 0; i < ids.size(); ++i) { if (i) std::cout << ","; std::cout << ids[i]; }
        std::cout << "]";
    }
    std::cout << ",[";
    auto hashes = tokenizer.encode("##");
    for (size_t i = 0; i < hashes.size(); ++i) { if (i) std::cout << ","; std::cout << hashes[i]; }
    std::cout << "]]";
}
''')
            executable = root / 'bytes'
            subprocess.run([
                'xcrun', 'clang++', '-std=c++17', '-O2', '-I' + str(source / 'cactus/engine'),
                str(cpp), str(library), '-framework', 'Accelerate', '-framework', 'CoreML',
                '-framework', 'Foundation', '-o', str(executable)
            ], check=True, capture_output=True)
            result = subprocess.run([str(executable), str(model)], check=True, text=True, capture_output=True)
            self.assertEqual(json.loads(result.stdout), expected)


if __name__ == '__main__':
    unittest.main()
