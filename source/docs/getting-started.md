**Dflat** consists two parts:

 1. `dflatc` compiler that takes a [flatbuffers schema](https://google.github.io/flatbuffers/flatbuffers_guide_writing_schema.html) and generate Swift code from it;

 2. **Dflat** runtime with very minimal API footprint to interact with.

The **Dflat** runtime uses SQLite as the storage backend. The design itself can support other backends such as [libmdbx](https://github.com/erthink/libmdbx) in the future. The only hard dependency is flatbuffers.

To use **Dflat**, you should first use `dflatc` compiler to generate data model from flatbuffers schema, include the generated code in your project, and then use **Dflat** runtime to interact with the data models.

## Installation

**Dflat** at the moment requires [Bazel](https://github.com/bazelbuild/bazel). To be more precise, **Dflat** runtime can be installed with either [Swift Package Manager](https://swift.org/package-manager/) or Bazel. But the `dflatc` compiler requires Bazel to build relevant parts.

You can install Bazel on macOS following [this guide](https://docs.bazel.build/versions/3.3.0/install-os-x.html).

### Install with Bazel

If your project is already managed by Bazel, **Dflat** provides fully-integrated tools from code generation to library dependency management. Simply add **Dflat** to your `WORKSPACE`:

```python
git_repository(
  name = "dflat",
  remote = "https://github.com/liuliu/dflat.git",
  commit = "88aec220642bb5e416074bc8b8a4e5c8b86a61c2",
  shallow_since = "1604112303 -0400"
)

load("@dflat//:deps.bzl", "dflat_deps")

dflat_deps()
```

For your `swift_library`, you can now add a new schema like this:

```python

load("@dflat//:dflat.bzl", "dflatc")

dflatc(
  name = "post_schema",
  src = "post.fbs"
)

swift_library(
  ...
  srcs = [
    ...
    ":post_schema"
  ],
  deps = [
    ...
    "@dflat//:SQLiteDflat"
  ]
)
```

### Install with Swift Package Manager

You can use `dflatc` compiler to manually generate code from flatbuffers schema.

```
./dflatc.py --help
```

You can now add the generated source code to your project and then proceed to add **Dflat** runtime with Swift Package Manager:

```swift
.package(name: "Dflat", url: "https://github.com/liuliu/dflat.git", from: "0.3.0")
```

## Example

Assuming you have a `post.fbs` file somewhere look like this:

```
enum Color: byte {
  Red = 0,
  Green,
  Blue = 2
}

table TextContent {
  text: string;
}

table ImageContent {
  images: [string];
}

union Content {
  TextContent,
  ImageContent
}

table Post {
  title: string (primary); // This is the primary key
  color: Color;
  tag: string;
  priority: int (indexed); // This property is indexed
  content: Content;
}

root_type Post; // This is important, it says the Post object will be the one Dflat manages.
```

You can then ether use `dflatc` compiler to manually generate code from the schema:

```
./dflatc.py -o ../PostExample ../PostExample/post.fbs
```

Or use `dflatc` rule from Bazel:

```python
dflatc(
  name = "post_schema",
  src = "post.fbs"
)
```

If everything checks out, you should see 4 files generated in `../PostExample` directory: `post_generated.swift`, `post_data_model_generated.swift`, `post_mutating_generated.swift`, `post_query_generated.swift`. Adding them to your project.

Now you can do basic Create-Read-Update-Delete (CRUD) operations on the `Post` object.

```swift
import Dflat
import SQLiteDflat

let dflat = SQLiteWorkspace(filePath: filePath, fileProtectionLevel: .noProtection)
```

Create:

```swift
var createdPost: Post? = nil
dflat.performChanges([Post.self], changesHandler: { (txnContext) in
  let creationRequest = PostChangeRequest.creationRequest()
  creationRequest.title = "first post"
  creationRequest.color = .red
  creationRequest.content = .textContent(TextContent(text: "This is my very first post!"))
  guard let inserted = try? txnContent.submit(creationRequest) else { return } // Alternatively, you can use txnContent.try(submit: creationRequest) which won't return any result and do "reasonable" error handling.
  if case let .inserted(post) = inserted {
    createdPost = post
  }
}) { succeed in
  // Transaction Done
}
```

Read:

```swift
let posts = dflat.fetch(for: Post.self).where(Post.title == "first post")
```

Update:

```swift
dflat.performChanges([Post.self], changesHandler: { (txnContext) in
  let post = posts[0]
  let changeRequest = PostChangeRequest.changeRequest(post)
  changeRequest.color = .green
  txnContent.try(submit: changeRequest)
}) { succeed in
  // Transaction Done
}
```

Delete:

```swift
dflat.performChanges([Post.self], changesHandler: { (txnContext) in
  let post = posts[0]
  let deletionRequest = PostChangeRequest.deletionRequest(post)
  txnContent.try(submit: deletionRequest)
}) { succeed in
  // Transaction Done
}
```

You can subscribe changes to either a query, or an object. For an object, the subscription ends when the object was deleted. For queries, the subscription won't complete unless cancelled. There are two sets of APIs for this, one is vanilla callback-based, the other is based on [Combine](https://developer.apple.com/documentation/combine). I will show the **Combine** one here.

Subscribe a live query:

```swift
let cancellable = dflat.publisher(for: Post.self)
  .where(Post.color == .red, orderBy: [Post.priority.descending])
  .subscribe(on: DispatchQueue.global())
  .sink { posts in
    print(posts)
  }
```

Subscribe to an object:

```swift
let cancellable = dflat.pulisher(for: posts[0])
  .subscribe(on: DispatchQueue.global())
  .sink { post in
    switch post {
    case .updated(newPost):
      print(newPost)
    case .deleted:
      print("deleted, this is completed.")
    }
  }
```
