//
//  CombineTest.swift
//  RxTest
//
//  Created by Igor Skovorodkin on 27.12.2021.
//

import Foundation
import Combine

class CombineTest {
    static let shared = CombineTest()

    var cancellabels: Set<AnyCancellable> = []

    let state1: CurrentValueSubject<State, Never> = .init(.init(count: 0))
    let state2: CurrentValueSubject<State, Never> = .init(.init(count: 0))

    let event1: PassthroughSubject<Event, Never> = .init()
    let event2: PassthroughSubject<Event, Never> = .init()

    init() {
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
            .sink(receiveValue: { [unowned self] state in
                self.state1.send(state)
            })
            .store(in: &cancellabels)

        event2
            .with(latestFrom: state2)
            .with(latestFrom: state1) { ($0.0, $0.1, $1) }
            .map { event, state, other in
                return state
            }
            .sink(receiveValue: { [unowned self] state in
                self.state2.send(state)
            })
            .store(in: &cancellabels)
    }

    func reproduceDeadlock1() {
        DispatchQueue.global().async {
            self.event1.send(.event)
            self.event1.send(.event)
            self.event1.send(.event)
        }

        DispatchQueue.global().async {
            self.event2.send(.event)
            self.event2.send(.event)
            self.event2.send(.event)
        }
    }

    // MARK: `with(latestFrom:)` & `combineLatest()` deadlock

    func observeDeadlock2() {

        event1
            .with(latestFrom: state1.combineLatest(state2)) { ($0, $1.0, $1.1) }
            .map { _, _, _ in
                return State(count: 2)
            }
            .sink(receiveValue: { [unowned self] state in
                self.state1.send(state)
            })
            .store(in: &cancellabels)
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

/// `with(latestFrom:)` implementation for Combine publisher.
public extension Publisher where Failure == Never {
    func with<Other: Publisher, MapOutput>(
        latestFrom other: Other,
        transform: @escaping (Output, Other.Output) -> MapOutput
    ) -> AnyPublisher<MapOutput, Never> where Other.Failure == Never {
        self.map { (value: $0, token: UUID()) }
            .combineLatest(other)
            .removeDuplicates(by: { $0.0.token == $1.0.token })
            .map { transform($0.value, $1) }
            .eraseToAnyPublisher()
    }

    func with<Other: Publisher>(latestFrom other: Other) ->
    AnyPublisher<(Output, Other.Output), Never> where Other.Failure == Never {
        self.with(latestFrom: other, transform: { ($0, $1) })
    }
}
