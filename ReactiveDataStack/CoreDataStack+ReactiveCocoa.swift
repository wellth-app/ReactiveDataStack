import CoreData
import ReactiveCocoa
import Result
import CoreDataStack


extension CoreDataStack {
    func persistProducer() -> SignalProducer<Bool, NSError> {
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
    
    func performInNewBackgroundContextProducer() -> SignalProducer<NSManagedObjectContext, NoError> {
        return SignalProducer { observer, _ in
            self.performInNewBackgroundContext { backgroundContext in
                observer.sendNext(backgroundContext)
                observer.sendCompleted()
            }
        }
    }
    
    func performInMainContextProducer() -> SignalProducer<NSManagedObjectContext, NoError> {
        return mainContext.performBlockProducer()
    }
    
    func performInNewMainContextChildContextProducer(name: String? = nil) -> SignalProducer<NSManagedObjectContext, NoError> {
        return performInConcurrentContextProducer(name, parentContext: mainContext)
    }
    
    func performInConcurrentContextProducer(name: String? = nil, parentContext: NSManagedObjectContext? = nil) -> SignalProducer<NSManagedObjectContext, NoError> {
        return newBackgroundContext(name, parentContext: parentContext).performBlockProducer()
    }
}