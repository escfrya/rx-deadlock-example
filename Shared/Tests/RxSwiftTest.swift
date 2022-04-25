//
//  RxSwiftTest.swift
//  RxTest
//
//  Created by Igor Skovorodkin on 27.12.2021.
//

import Foundation
import RxSwift

class RxSwiftTest {
    static let shared = RxSwiftTest()

    let bag = DisposeBag()

    let state1: BehaviorSubject<State> = .init(value: State(count: 0))
    let state2: BehaviorSubject<State> = .init(value: State(count: 0))

    let event1: PublishSubject<Event> = .init()
    let event2: PublishSubject<Event> = .init()

    init() {
        observeDeadlock1()
        observeDeadlock2()
    }

    // MARK: `with(latestFrom:)` deadlock

    func observeDeadlock1() {
        event1
            .withLatestFrom(state1) { ($0, $1) }
            .withLatestFrom(state2) { ($0.0, $0.1, $1) }
            .map { event, state, other in
                return state
            }
            .subscribe(onNext: { [unowned self] state in
                self.state1.onNext(state)
            })
            .disposed(by: bag)

        event2
            .withLatestFrom(state2) { ($0, $1) }
            .withLatestFrom(state1) { ($0.0, $0.1, $1) }
            .map { event, state, other in
                return state
            }
            .subscribe(onNext: { [unowned self] state in
                self.state2.onNext(state)
            })
            .disposed(by: bag)
    }

    func reproduceDeadlock1() {
        DispatchQueue.global().async {
            self.event1.onNext(.event)
        }

        DispatchQueue.global().async {
            self.event2.onNext(.event)
        }
    }

    // MARK: `with(latestFrom:)` & `combineLatest()` deadlock

    func observeDeadlock2() {
        event1
            .withLatestFrom(Observable.combineLatest(state1, state2)) { ($0, $1.0, $1.1) }
            .map { _, _, _ in
                return State(count: 2)
            }
            .subscribe(onNext: { [unowned self] state in
                self.state1.onNext(state)
            })
            .disposed(by: bag)
    }

    func reproduceDeadlock2() {
        DispatchQueue.global().async {
            self.event1.onNext(.event)
        }

        DispatchQueue.global().async {
            self.state2.onNext(State(count: 0))
            self.state2.onNext(State(count: 0))
            self.state2.onNext(State(count: 0))
        }
    }
}
