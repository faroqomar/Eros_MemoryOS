#include "whisper.h"
#include <fstream>
#include <vector>

extern "C" bool whisper_probe(const char *model, const char *pcm) {
    std::ifstream input(pcm, std::ios::binary | std::ios::ate);
    if (!input) return false;
    auto bytes = input.tellg();
    if (bytes <= 0 || bytes % sizeof(float)) return false;
    std::vector<float> samples(static_cast<size_t>(bytes) / sizeof(float));
    input.seekg(0);
    if (!input.read(reinterpret_cast<char *>(samples.data()), bytes)) return false;
    auto context_params = whisper_context_default_params();
    context_params.use_gpu = false;
    auto *context = whisper_init_from_file_with_params(model, context_params);
    if (!context) return false;
    auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = 4;
    params.language = "en";
    params.print_progress = params.print_realtime = params.print_timestamps = false;
    const int result = whisper_full(context, params, samples.data(), samples.size());
    bool text = false;
    for (int i = 0; result == 0 && i < whisper_full_n_segments(context); ++i) {
        const char *segment = whisper_full_get_segment_text(context, i);
        text = text || (segment && *segment);
    }
    whisper_free(context);
    return result == 0 && text;
}
