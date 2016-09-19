extension CoreDataStack {
    public func persistProducer() -> SignalProducer<Bool, NSError> {
        return SignalProducer { observer, _ in
            self.persistWithCompletion { error in
                if let error = error as? NSError {
                    observer.send(error: error)
                } else {
                    observer.send(value: true)
                    observer.sendCompleted()
                }
            }
        }
    }
}
