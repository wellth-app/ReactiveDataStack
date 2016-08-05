import ReactiveCocoa
import Result


public struct CoreDataScheduler: SchedulerType {
    let managedObjectContext: NSManagedObjectContext
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    public func schedule(action: () -> ()) -> Disposable? {
        let disposable = SimpleDisposable()
        
        managedObjectContext.performBlock {
            if disposable.disposed {
                return
            }
            
            action()
        }
        
        return disposable
    }
}