//
//  Service1.swift
//  RxTest
//
//  Created by Igor Skovorodkin on 03.09.2021.
//

import Foundation
import ReactiveKit

class ReactiveKitTest {
    static let shared = ReactiveKitTest()

    let state1: SafeReplayOneSubject<State> = .init()
    let state2: SafeReplayOneSubject<State> = .init()

    let event1: PassthroughSubject<Event, Never> = .init()
    let event2: PassthroughSubject<Event, Never> = .init()

    init() {
        state1.send(State(count: 0))
        state2.send(State(count: 0))

        observeDeadlock1()
        observeDeadlock2()
    }

    // MARK: `with(latestFrom:)` deadlock

    func observeDeadlock1() {
        event1
            .with(latestFrom: state1)
            .with(latestFrom: state2) { ($0.0, $0.1, $1) }
            .map { event, state, other in
                return state
            }
//            .receive(on: DispatchQueue(label: "event1"))
            .bind(to: state1)

        event2
            .with(latestFrom: state2)
            .with(latestFrom: state1) { ($0.0, $0.1, $1) }
            .map { event, state, other in
                return state
            }
            .bind(to: state2)
    }

    func reproduceDeadlock1() {
        DispatchQueue.global().async {
            self.event1.send(.event)
        }

        DispatchQueue.global().async {
            self.event2.send(.event)
        }
    }

    // MARK: `with(latestFrom:)` & `combineLatest()` deadlock

    func observeDeadlock2() {
        event1
            .with(latestFrom: combineLatest(state1, state2)) { ($0, $1.0, $1.1) }
            .map { _, _, _ in
                return State(count: 2)
            }
//            .receive(on: DispatchQueue.global())
            .bind(to: state1)
    }

    func reproduceDeadlock2() {
        DispatchQueue.global().async {
            self.event1.send(.event)
        }

        DispatchQueue.global().async {
            self.state2.send(State(count: 0))
            self.state2.send(State(count: 0))
            self.state2.send(State(count: 0))
        }
    }
}

/// `with(latestFrom:)` implementation via `combineLatest(with:)` for correct comparision with Combine.
extension SignalProtocol {
    func with<Other: SignalProtocol, MapOutput>(
        latestFrom1 other: Other,
        transform: @escaping (Element, Other.Element) -> MapOutput
    ) -> Signal<MapOutput, Error> where Error == Other.Error {
        return self.map { (value: $0, token: UUID()) }
            .combineLatest(with: other)
            .removeDuplicates(by: { $0.0.token == $1.0.token })
            .map { transform($0.value, $1) }
    }

    func with<Other: SignalProtocol>(latestFrom1 other: Other) -> Signal<(Element, Other.Element), Error> where Error == Other.Error {
        return with(latestFrom1: other, transform: { ($0, $1) })
    }
}
