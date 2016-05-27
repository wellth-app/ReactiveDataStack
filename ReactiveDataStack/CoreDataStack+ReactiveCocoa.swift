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
    
    public func performInMainContextProducer<E: ErrorType>() -> SignalProducer<NSManagedObjectContext, E> {
        return mainContext
            .performBlockProducer()
            .promoteErrors(E)
    }
    
    public func performInNewMainContextChildContextProducer<E: ErrorType>(name: String? = nil) -> SignalProducer<NSManagedObjectContext, E> {
        return performInConcurrentContextProducer(name, parentContext: mainContext)
    }
    
    public func performInConcurrentContextProducer<E: ErrorType>(name: String? = nil, parentContext: NSManagedObjectContext? = nil) -> SignalProducer<NSManagedObjectContext, E> {
        return newBackgroundContext(name, parentContext: parentContext)
            .performBlockProducer()
            .promoteErrors(E)
    }
}