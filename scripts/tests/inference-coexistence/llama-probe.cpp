#include "llama.h"
#include <cstdio>
#include <string>
#include <vector>

extern "C" bool whisper_probe(const char *, const char *);

static bool llama_probe(const char *path) {
    llama_backend_init();
    auto model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    auto *model = llama_model_load_from_file(path, model_params);
    if (!model) return false;
    auto params = llama_context_default_params();
    params.n_ctx = 2048;
    params.n_batch = 2048;
    params.n_threads = params.n_threads_batch = 4;
    auto *context = llama_init_from_model(model, params);
    if (!context) { llama_model_free(model); return false; }
    const auto *vocab = llama_model_get_vocab(model);
    const std::string prompt = "Hello";
    std::vector<llama_token> tokens(64);
    int count = llama_tokenize(vocab, prompt.c_str(), prompt.size(), tokens.data(), tokens.size(), true, true);
    auto *sampler = llama_sampler_init_greedy();
    bool ok = sampler && count > 0 && llama_decode(context, llama_batch_get_one(tokens.data(), count)) == 0;
    for (int i = 0; ok && i < 4; ++i) {
        auto token = llama_sampler_sample(sampler, context, -1);
        if (llama_vocab_is_eog(vocab, token)) break;
        ok = llama_decode(context, llama_batch_get_one(&token, 1)) == 0;
    }
    if (sampler) llama_sampler_free(sampler);
    llama_free(context);
    llama_model_free(model);
    llama_backend_free();
    return ok;
}

int main(int argc, char **argv) {
    if (argc != 5) return 2;
    const bool whisper_first = std::string(argv[4]) == "whisper-first";
    bool ok = whisper_first
        ? whisper_probe(argv[2], argv[3]) && llama_probe(argv[1])
        : llama_probe(argv[1]) && whisper_probe(argv[2], argv[3]);
    if (!ok) return 1;
    std::printf("PASS: %s model loading and decoding\n", argv[4]);
}
