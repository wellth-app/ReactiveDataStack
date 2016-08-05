import CoreData
import ReactiveCocoa
import Result
import CoreDataStack


extension CoreDataStack {
    public func persistProducer() -> SignalProducer<Bool, NSError> {
        return SignalProducer { observer, _ in
            self.persistWithCompletion { error in
                if let error = error as? NSError {
                    observer.sendFailed(error)
                } else {
                    observer.sendNext(true)
                    observer.sendCompleted()
                }
            }
        }
    }
}