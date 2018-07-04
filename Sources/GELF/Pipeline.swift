// Copyright 2018 Andreas Stührk <andy@hammerhartes.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


/// A pipeline. Processes an input through multiple steps and potentially
/// produces some output. Every stage can also decide to stop the processing.
public struct Pipeline<Input, Output> {

    public let process: (Input) -> Output?

    public init<S : Stage>(stage: S) where S.Input == Input, S.Output == Output {
        self.process = { stage.process($0) }
    }

    /// Create a new pipeline consisting of the given function.
    public init(_ f: @escaping (Input) -> Output?) {
        self.process = f
    }

    /// Adds the given function to the end of the pipeline. Returns the new pipeline.
    public func append<NewOutput>(_ f: @escaping (Output) -> NewOutput) -> Pipeline<Input, NewOutput> {
        return Pipeline<Input, NewOutput> {
            self.process($0).map(f)
        }
    }

    /// Adds the given stage to the end of the pipeline. Returns the new pipeline.
    public func append<S : Stage>(stage: S) -> Pipeline<Input, S.Output> where Output == S.Input {
        return Pipeline<Input, S.Output> {
            self.process($0).flatMap(stage.process)
        }
    }

    /// Appends the given pipeline to the end of this pipeline. Returns the new pipeline.
    public func append<OtherOutput>(pipeline: Pipeline<Output, OtherOutput>) -> Pipeline<Input, OtherOutput> {
        return Pipeline<Input, OtherOutput> {
            self.process($0).flatMap(pipeline.process)
        }
    }
}

/// A stage in the event processing pipeline. Mostly for convenience so you don't
// have to pass around closures.
public protocol Stage {
    associatedtype Input
    associatedtype Output

    func process(_ event: Input) -> Output?
}


// MARK: Predefined stages
// Some handy event pipeline stages

/// Identity stage. Returns the input.
public struct IdentityStage<Input> {
}
extension IdentityStage: Stage {
    public func process(_ event: Input) -> Input? {
        return event
    }
}

/// Branches a pipeline into multiple pipelines. One pipeline is considered
/// the "producer" pipeline and will be taken as return value for this stage.
/// The other pipelines are considered consumers and their return values
/// will be ignored. All pipelines receive the input.
public struct Branch<Input, Output> {
    let producer: Pipeline<Input, Output>
    let consumers: [(Input) -> Void]

    public init<A>(producer: Pipeline<Input, Output>, _ second: Pipeline<Input, A>) {
        self.init(producer: producer, consumers: [{ _ = second.process($0) }])
    }

    public init<A, B>(producer: Pipeline<Input, Output>, _ a: Pipeline<Input, A>, _ b: Pipeline<Input, B>) {
        self.init(producer: producer, consumers: [{ _ = a.process($0) }, { _ = b.process($0) }])
    }

    public init<A, B, C>(producer: Pipeline<Input, Output>,
                         _ a: Pipeline<Input, A>,
                         _ b: Pipeline<Input, B>,
                         _ c: Pipeline<Input, C>) {
        self.init(producer: producer, consumers: [
            { _ = a.process($0) }, { _ = b.process($0) }, { _ = c.process($0) }
        ])
    }

    private init(producer: Pipeline<Input, Output>, consumers: [(Input) -> Void]) {
        self.producer = producer
        self.consumers = consumers
    }
}

extension Branch: Stage {
    public func process(_ event: Input) -> Output? {
        for consumer in consumers {
            consumer(event)
        }
        return producer.process(event)
    }
}

/// Filters log events based on their level.
public struct ThresholdFilter {
    private let thresholdLevel: LogLevel

    public init(thresholdLevel: LogLevel) {
        self.thresholdLevel = thresholdLevel
    }
}

extension ThresholdFilter: Stage {
    public typealias Input = LogEvent
    public typealias Output = LogEvent

    public func process(_ event: LogEvent) -> LogEvent? {
        if event.level.rawValue <= thresholdLevel.rawValue {
            return event
        } else {
            return .none
        }
    }
}
