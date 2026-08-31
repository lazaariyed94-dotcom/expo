import Testing
import Foundation

@testable import EXUpdates

/// An observer that only needs an identity, which is all the manager uses.
private final class StubObserver: UpdatesEventManagerObserver {
  var receivedContext: UpdatesStateContext?
  func onStateMachineContextEvent(context: UpdatesStateContext) {
    receivedContext = context
  }
}

// On a reload, the incoming module sets itself as the observer while the outgoing module clears
// itself, from two different threads. Unsynchronized, concurrent reads/writes to the observer slot
// race, and an unguarded remove from the outgoing module can also clear the incoming observer if it
// runs last.
@Suite("QueueUpdatesEventManager")
struct QueueUpdatesEventManagerTests {
  @Test
  func `sends the context to the current observer`() {
    let manager = QueueUpdatesEventManager(logger: UpdatesLogger())
    let observer = StubObserver()
    manager.setObserver(observer)

    let context = UpdatesStateContext()
    manager.sendStateMachineContextEvent(context: context)

    #expect(observer.receivedContext != nil)
  }

  @Test
  func `removeObserver only clears the slot if it still points at the caller`() {
    let manager = QueueUpdatesEventManager(logger: UpdatesLogger())
    let first = StubObserver()
    let second = StubObserver()

    manager.setObserver(first)
    manager.setObserver(second)
    // A stale remove from the observer that lost the race must not clear the current one.
    manager.removeObserver(first)
    manager.sendStateMachineContextEvent(context: UpdatesStateContext())

    #expect(second.receivedContext != nil)
    #expect(first.receivedContext == nil)
  }

  @Test
  func `removeObserver clears the slot when it matches`() {
    let manager = QueueUpdatesEventManager(logger: UpdatesLogger())
    let observer = StubObserver()

    manager.setObserver(observer)
    manager.removeObserver(observer)
    manager.sendStateMachineContextEvent(context: UpdatesStateContext())

    #expect(observer.receivedContext == nil)
  }

  @Test
  func `set and remove from many threads at once does not crash`() {
    let manager = QueueUpdatesEventManager(logger: UpdatesLogger())
    let observers = (0..<500).map { _ in StubObserver() }

    DispatchQueue.concurrentPerform(iterations: observers.count) { index in
      manager.setObserver(observers[index])
      manager.removeObserver(observers[index])
    }

    manager.sendStateMachineContextEvent(context: UpdatesStateContext())
  }
}
