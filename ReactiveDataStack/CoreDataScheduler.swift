/// A scheduler that ensures execution occurs on the 
/// `managedObjectContext`s thread.
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