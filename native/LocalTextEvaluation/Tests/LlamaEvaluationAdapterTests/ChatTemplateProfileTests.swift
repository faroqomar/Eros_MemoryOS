import AIEvaluationCore
import Foundation
import Testing

@testable import LlamaEvaluationAdapter

struct ChatTemplateProfileTests {
  private let prompt =
    "<|im_start|>user\nFictional source: هدى طلبت خمس دقائق.\n<|im_end|>\n<|im_start|>assistant\n"

  @Test(arguments: ["qwen3", "qwen35"])
  func ordinaryGenerationClosesPreparationWithoutChangingOriginalPrompt(architecture: String) throws
  {
    let completed = try ReviewedLlamaChatTemplate.complete(prompt, architecture: architecture)
    #expect(Array(completed.utf8.prefix(prompt.utf8.count)) == Array(prompt.utf8))
    #expect(completed.hasSuffix("<|im_start|>assistant\n<think>\n\n</think>\n\n"))
    #expect(completed.components(separatedBy: "<think>").count == 2)
    #expect(completed.components(separatedBy: "</think>").count == 2)
  }

  @Test(arguments: [
    "<|im_start|>assistant", "<|im_start|>assistant\n<think>\n",
    "<|im_start|>assistant\n<think>\n\n</think>\n\n", "<|im_start|>user\n",
    "<|im_start|>assistant\n ", "<|im_start|>assistant\r\n",
  ])
  func qwen35RejectsUnexpectedOrAlreadyCompletedGenerationBoundary(suffix: String) {
    #expect(throws: EvaluationError.self) {
      try ReviewedLlamaChatTemplate.complete("Fictional source\n" + suffix, architecture: "qwen35")
    }
  }

  @Test(arguments: ["", "qwen2", "qwen35moe", "Qwen3.5-4B", "qwen35 "])
  func onlyExactReviewedArchitectureNamesSelectTheProfile(architecture: String) throws {
    #expect(try ReviewedLlamaChatTemplate.complete(prompt, architecture: architecture) == prompt)
  }
}
