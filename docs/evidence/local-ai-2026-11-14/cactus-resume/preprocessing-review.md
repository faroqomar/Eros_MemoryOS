# Qwen3 embedding preprocessing review

Reviewed 2026-11-15 against the [official Qwen model card](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B#transformers-usage), the pinned Cactus conversion, and engine v1.14 commit `40a7123b0788f5b38c5fe0daa0d909b4286fe773`.

The model card selects the last unpadded hidden-state row and applies L2 normalization. It adds an English task instruction to queries and leaves documents without instructions. A chat completion template is not part of that example.

The adapter already adds its recorded English retrieval instruction to each query, passes documents as their source text and requests normalization. The pinned native BPE `encode` path tokenizes the supplied string without adding a chat template, BOS/EOS or batch padding. The converted `tokenizer_config.txt` selects BPE with no additional normalizer. We submit one string per call, so the last token is unpadded. We do not claim numerical/token parity with a separate Transformers implementation from these checks alone.

A required setup defect existed in the original Cactus `cactus_embed`: it calls `Model::get_embeddings(tokens,true,normalize)`, and that method averages the token rows. This differs from Qwen's published pooling procedure. The first host report therefore remains a labeled mean-pooling baseline, rather than a result for the corrected setup.

The retained local-evaluation patch adds an explicit `cactus_memoryos_evaluation_embed_last_token` C export. It uses the existing native `get_embeddings(tokens,false,false)` path, selects the last hidden-state row and normalizes that row. It checks tensor shape, buffer size, finite values and nonzero norm. It leaves the upstream mean-pooling API unchanged and changes no model tensor/tokenizer file. The adapter calls the explicit export. Its native contract checks 1024-dimensional normalized output and verifies that the result differs from mean pooling on a multi-token input.

The corrected configuration retains CPU execution, four workers, the same instruction and threshold 0.35/top-3. The rerun does not tune the threshold to the shared fixture. Keep both source identities and raw reports when comparing them.
