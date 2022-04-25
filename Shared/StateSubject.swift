//
//  StateSubject.swift
//  RxTest
//
//  Created by Igor Skovorodkin on 27.12.2021.
//

import Foundation
import ReactiveKit

/// Attempt to avoid deadlock problem.
open class StateSubject<Element>: SubjectProtocol {

    private var _lastEvent: Signal<Element, Never>.Event?
    private var _terminalEvent: Signal<Element, Never>.Event?

    private let lock = NSRecursiveLock(name: "com.reactive_kit.state_subject.lock")

    private typealias Token = Int64
    private var nextToken: Token = 0

    private var observers: Atomic1<[(Token, Observer<Element, Never>)]> = Atomic1([])

    public private(set) var isTerminated: Bool = false

    public let disposeBag = DisposeBag()

    public init() {}

    open func on(_ event: Signal<Element, Never>.Event) {
        lock.lock()

        guard !isTerminated else { return }
        if event.isTerminal {
            _terminalEvent = event
        } else {
            _lastEvent = event
        }
        let observersValue = observers.value

        isTerminated = event.isTerminal

        lock.unlock()

        // Notify observers without lock
        for (_, observer) in observersValue {
            observer(event)
        }
    }

    open func observe(with observer: @escaping Observer<Element, Never>) -> Disposable {
        lock.lock(); defer { lock.unlock() }

        let (lastEvent, terminalEvent) = (_lastEvent, _terminalEvent)
        if let event = lastEvent {
            observer(event)
        }
        if let event = terminalEvent {
            observer(event)
        }

        let token = nextToken
        nextToken += 1
        observers.mutate {
            $0.append((token, observer))
        }
        return BlockDisposable { [weak self] in
            self?.observers.mutate {
                $0.removeAll(where: { (t, _) in t == token })
            }
        }
    }
}

extension StateSubject: BindableProtocol {
    public func bind(signal: Signal<Element, Never>) -> Disposable {
        return signal
            .prefix(untilOutputFrom: disposeBag.deallocated)
            .receive(on: ExecutionContext.nonRecursive())
            .observeNext { [weak self] element in
                guard let s = self else { return }
                s.on(.next(element))
            }
    }
}

final class Atomic1<T> {

    private var _value: T
    private let lock: NSLocking

    init(_ value: T, lock: NSLocking = NSRecursiveLock()) {
        self._value = value
        self.lock = lock
    }

    var value: T {
        get {
            lock.lock()
            let value = _value
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _value = newValue
            lock.unlock()
        }
    }

    func mutate(_ block: (inout T) -> Void) {
        lock.lock()
        block(&_value)
        lock.unlock()
    }

    func mutateAndRead(_ block: (T) -> T) -> T {
        lock.lock()
        let newValue = block(_value)
        _value = newValue
        lock.unlock()
        return newValue
    }

    func readAndMutate(_ block: (T) -> T) -> T {
        lock.lock()
        let oldValue = _value
        _value = block(_value)
        lock.unlock()
        return oldValue
    }
}
