# Namespace

**Dflat** schema supports namespace, as does flatbuffers schema. However, because Swift doesn't really support proper namespace, the namespace implementation relies on `public enum` and extensions. Thus, if you have namespace:

```
namespace Evolution.V1;

table Post {
  title: string (primary);
}

root_type Post;
```

You have to declare the namespace yourself. In your project, you need to have a Swift file contains following:

```swift
public enum Evolution {
  public enum V1 {
  }
}
```

And it will work. You can then access the `Post` object through `Evolution.V1.Post` or `typealias Post = Evolution.V1.Post`.
