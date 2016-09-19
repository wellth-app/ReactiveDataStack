/// A scheduler that ensures execution occurs on the 
/// `managedObjectContext`s thread.
public struct CoreDataScheduler: SchedulerProtocol {
    let managedObjectContext: NSManagedObjectContext
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    public func schedule(_ action: @escaping () -> ()) -> Disposable? {
        let disposable = SimpleDisposable()
        
        managedObjectContext.perform {
            if disposable.isDisposed {
                return
            }
            
            action()
        }
        
        return disposable
    }
}
