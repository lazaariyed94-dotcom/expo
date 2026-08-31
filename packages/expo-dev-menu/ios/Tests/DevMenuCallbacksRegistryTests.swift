import Testing
import Foundation

@testable import EXDevMenu

/// Runs `body` once per index, concurrently, and returns once every call has finished.
private func concurrently(_ count: Int, _ body: @escaping (Int) -> Void) {
  DispatchQueue.concurrentPerform(iterations: count) { index in
    body(index)
  }
}

// DevMenuModule.OnDestroy resets the callback list from the outgoing context's JS thread while the
// incoming context's JS thread appends to it via addDevMenuCallbacks, so the registry is written
// from more than one thread. Unsynchronized, concurrent mutation of a plain Array corrupts its
// buffer and crashes the process with SIGSEGV.
@Suite("DevMenuCallbacksRegistry")
struct DevMenuCallbacksRegistryTests {
  @Test
  func `keeps the last replace when several threads replace at once`() {
    let registry = DevMenuCallbacksRegistry()

    concurrently(500) { index in
      registry.replace(with: [DevMenuManager.Callback(name: "callback-\(index)", shouldCollapse: true)])
    }

    // Every replace is a full-array swap, so the result is always exactly one of the writes,
    // never a corrupted mix of them.
    #expect(registry.callbacks.count == 1)
  }

  @Test
  func `reads a consistent snapshot while writes are in flight`() {
    let registry = DevMenuCallbacksRegistry()
    let callbackNames = (0..<50).map { "callback-\($0)" }

    concurrently(callbackNames.count) { index in
      let name = callbackNames[index]
      registry.replace(with: [DevMenuManager.Callback(name: name, shouldCollapse: true)])
      // A concurrent reader always sees a fully-formed array, never a partially written one.
      #expect(registry.callbacks.count == 1)
    }
  }

  @Test
  func `starts out empty`() {
    let registry = DevMenuCallbacksRegistry()

    #expect(registry.callbacks.isEmpty)
  }
}
