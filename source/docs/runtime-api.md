# Runtime API

**Dflat** runtime has very minimal API footprint. There are about 15 APIs in total from 2 objects.

## Transactions

```swift
func Workspace.performChanges(_ transactionalObjectTypes: [Any.Type], changesHandler: @escaping (_ transactionContext: TransactionContext) -> Void, completionHandler: ((_ success: Bool) -> Void)? = nil)
```

The API takes a `changesHandler` closure, where you can perform transactions such as object creations, updates or deletions. These mutations are performed through `ChangeRequest` objects.

The first parameter specifies relevant object you are going to transact with. If you read or update any objects that is not specified here, an assertion will be triggered.

When the transaction is done, the `completionHandler` closure will be triggered, and it will let you know whether the transaction is successful or not.

The transaction will be performed in a background thread, exactly which one shouldn't be your concern. Two different objects can have transactions performed concurrently, it follows strict serializable protocol in that case.

```swift
func TransactionContext.submit(_ changeRequest: ChangeRequest) throws -> UpdatedObject
func TransactionContext.try(submit: ChangeRequest) -> UpdatedObject?
func TransactionContext.abort() -> Bool
```

You can interact with **Dflat** with above APIs in a transaction. It handles data mutations through `submit`. Note that errors are possible. For example, if you created an object with the same primary key twice (you should use `upsertRequest` if this is expected). `try(submit:` method simplified the `try? submit` dance in case you don't want to know the returned value. It will fatal if there are conflict primary keys, otherwise will swallow other types of errors (such as disk full). When encountered any other types of errors, **Dflat** will simply fail the whole transaction. `abort` method will explicitly abort a transaction. All submissions before and after this call will have no effect.

## Data Fetching

```swift
func Workspace.fetch(for ofType: Element.Type).where(ElementQuery, limit = .noLimit, orderBy = []) -> FetchedResult<Element>
func Workspace.fetch(for ofType: Element.Type).all(limit = .noLimit, orderBy = []) -> FetchedResult<Element>
func Workspace.fetchWithinASnapshot<T>(_: () -> T) -> T
```

Data fetching happens synchronously. You can specify conditions in the `where` clause, such as `Post.title == "first post"` or `Post.priority > 100 && Post.color == .red`. The returned `FetchedResult<Element>` acts pretty much like an array. The object itself (`Element`) is immutable, thus, either the object or the `FetchedResult<Element>` is safe to pass around between threads.

`fetchWithinASnapshot` provides a consistent view if you are going to fetch multiple objects:

```swift
let result = dflat.fetchWithinASnapshot { () -> (firstPost: FetchedResult<Post>, highPriPosts: FetchedResult<Post>) in
  let firstPost = dflat.fetch(for: Post.self).where(Post.title == "first post")
  let highPriPosts = dflat.fetch(for: Post.self).where(Post.priority > 100 && Post.color == .red)
  return (firstPost, highPriPosts)
}
```

This is needed because **Dflat** can do transactions in between fetch for `firstPost` and `highPriPosts`. The `fetchWithinASnapshot` won't stop that transaction, but will make sure it only observe the view from fetching for `firstPost`.

## Data Subscription

```swift
func Workspace.subscribe<Element: Equatable>(fetchedResult: FetchedResult<Element>, changeHandler: @escaping (_: FetchedResult<Element>) -> Void) -> Subscription
func Workspace.subscribe<Element: Equatable>(object: Element, changeHandler: @escaping (_: SubscribedObject<Element>) -> Void) -> Subscription
```

The above are the native subscription APIs. It subscribes changes to either a `fetchedResult` or an object. For object, it will end when object deleted. The subscription is triggered before a `completionHandler` on a transaction triggered.

```swift
func Workspace.publisher<Element: Equatable>(for: Element) -> AtomPublisher<Element>
func Workspace.publisher<Element: Equatable>(for: FetchedResult<Element>) -> FetchedResultPublisher<Element>
func Workspace.publisher<Element: Equatable>(for: Element.Type).where(ElementQuery, limit = .noLimit, orderBy = []) -> QueryPublisher<Element>
func Workspace.publisher<Element: Equatable>(for: Element.Type).all(limit = .noLimit, orderBy = []) -> QueryPublisher<Element>
```

These are the **Combine** counter-parts. Besides subscribing to objects or `fetchedResult`, it can also subscribe to a query directly. What happens under the hood is the query will be made upon `subscribe` (hence, on whichever queue you provided if you did `subscribe(on:`), and subscribe the `fetchedResult` from then on.

## Close

```swift
func Workspace.shutdown(completion: (() -> Void)? = nil)
```

This will trigger the **Dflat** shutdown. All transactions made to **Dflat** after this call will fail. Transactions initiated before this will finish normally. Data fetching after this will return empty results. Any data fetching triggered before this call will finish normally, hence the `completion` part. The `completion` closure, if supplied, will be called once all transactions and data fetching initiated before `shutdown` finish.
