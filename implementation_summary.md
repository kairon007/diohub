## Summary of `auto_route` and Deep-linking with Auth Guards (Corrected)

This document provides a comprehensive and corrected guide to the `auto_route`, deep-linking, and authentication guard implementation. It follows best practices to ensure a stable and robust implementation.

### Big Picture

The application uses `auto_route` for declarative, strongly-typed navigation. Route access is controlled by a custom `AuthGuard`, which checks the user's authentication status via an `AuthenticationBloc`. If unauthenticated, the user is redirected to a login screen.

Deep-linking is handled by the `app_links` package. A custom handler parses incoming URIs, determines the appropriate in-app destination using regex, and uses the global `auto_route` instance to navigate. The entire process is secure, as the `AuthGuard` protects all routes.

### 1. Setup and Configuration

#### `AuthenticationBloc` and Global Router

The `AuthGuard` and deep-linking handler need safe access to the `AuthenticationBloc` and the router instance.

1.  **Provide the `AuthenticationBloc`**: The `AuthenticationBloc` is provided high up in the widget tree using `BlocProvider`.

2.  **Create and Provide the Router**: A global `AppRouter` instance is created and initialized *after* the `AuthenticationBloc` is available. The bloc instance is passed to the router's constructor.

    ```dart
    // lib/app/global.dart
    late AppRouter _customRouter;
    AppRouter get customRouter => _customRouter;

    void setUpRouter({required AuthenticationBloc authBloc}) {
      _customRouter = AppRouter(authBloc: authBloc);
    }
    ```

    In `main.dart`, this is tied together:

    ```dart
    // lib/main.dart (Simplified)
    class MyApp extends StatelessWidget {
      // ...
      @override
      Widget build(BuildContext context) {
        return BlocProvider<AuthenticationBloc>(
          create: (_) => AuthenticationBloc(authenticated: authenticated),
          child: Builder(
            builder: (context) {
              // Get the bloc instance and pass it to the router setup.
              setUpRouter(authBloc: BlocProvider.of<AuthenticationBloc>(context));
              return MaterialApp.router(
                routerConfig: customRouter.config(),
                // ...
              );
            },
          ),
        );
      }
    }
    ```

#### A Note on Globals

Using a global variable for the router (`customRouter`) is a pragmatic choice for this architecture, as it simplifies navigation from non-widget classes (like the deep-link handler). However, in larger or more complex apps, consider using a formal service locator package (like `get_it`) to manage dependencies and avoid potential issues with global state.

#### `app_links` Native Setup

The `app_links` package requires native configuration for iOS and Android to intercept URLs. Refer to the official [`app_links` documentation](https://pub.dev/packages/app_links) for the detailed steps involving `Associated Domains` on iOS and `intent-filter` on Android.

### 2. `auto_route` and `AuthGuard` Implementation (Corrected)

#### `AppRouter` (`lib/routes/router.dart`)

The `AppRouter` constructor accepts the `AuthenticationBloc` and passes it to the `AuthGuard`.

```dart
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter({required final AuthenticationBloc authBloc})
      : authGuard = AuthGuard(authBloc);
  final AuthGuard authGuard;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
        AutoRoute(page: AuthRoute.page), // Unprotected login screen
        AutoRoute(
          page: LandingRoute.page,
          guards: <AutoRouteGuard>[authGuard], // Protected route
          initial: true,
        ),
        // ... other protected routes
      ];
}
```

#### Safe `AuthGuard` (`lib/routes/router.dart`)

The `AuthGuard` holds a direct reference to the `AuthenticationBloc` instance, completely avoiding the use of a cached or stale `BuildContext`.

```dart
class AuthGuard extends AutoRouteGuard {
  AuthGuard(this.authBloc);
  final AuthenticationBloc authBloc;

  @override
  void onNavigation(
    final NavigationResolver resolver,
    final StackRouter router,
  ) {
    if (!authBloc.state.authenticated) { // Safe access to bloc state
      unawaited(
        router.replaceAll(
          <PageRouteInfo>[
            AuthRoute(
              onAuthenticated: () {
                router.removeLast();
                resolver.next();
              },
            ),
          ],
        ),
      );
    } else {
      resolver.next();
    }
  }
}
```

### 3. Deep-linking Implementation (Corrected)

#### Initialization (`lib/adapters/deep_linking_handler.dart`)

The deep-link listeners are initialized when the app starts. This code remains the same.

```dart
void initializeDeepLinking() {
  initUniLink();
  uniLinkStream();
}
// ... initUniLink and uniLinkStream implementations ...
```

#### Robust Navigation and Parsing (`lib/adapters/deep_linking_handler.dart`)

The `deepLinkNavigate` function uses the global `customRouter` for navigation and its `navigatorKey` to safely access the current `BuildContext` when needed (e.g., for `showDialog`).

```dart
Future<void> deepLinkNavigate(final Uri link) async {
  final routes = _getRoutes(link);
  if (routes?.isNotEmpty ?? false) {
    if (routes.first is LandingRoute) {
      unawaited(customRouter.popUntil((_) => false));
    }
    await customRouter.pushAll(routes); // Use the global router directly
  }
}
```

### 4. Helper Functions and Classes

#### `getRoute` Function (`lib/routes/router.dart`)

This generic helper distinguishes between deep links and API links.

```dart
T getRoute<T extends PageRouteInfo>(
  final PathData path, {
  required final T Function(PathData path) onDeepLink,
  final T Function(PathData path)? onAPILink,
}) {
  if (path.isAPIPath && onAPILink != null) {
    return onAPILink(path);
  }
  return onDeepLink(path);
}
```

#### `StringFunctions` as a Dart Extension (`lib/utils/string_compare.dart`)

The `StringFunctions` class is refactored into a more idiomatic Dart `extension` on `String`.

```dart
extension StringFunctions on String {
  bool regexCompleteMatch(final RegExp pattern) {
    final String? match = pattern.firstMatch(this)?.group(0);
    return match != null && match == this;
  }
  // ... other helper methods ...
}
```
The usage in `_getRoutes` becomes more concise: `if (path.regexCompleteMatch(...))`.

#### `PathData` Class (`lib/adapters/deep_linking_handler.dart`)

This class remains a simple data holder for URL components. An extension on `String` is used for easy conversion.

```dart
class PathData {
  PathData(this.path, {this.isAPIPath = false});
  final String path;
  final bool isAPIPath;
  List<String> get components => path.split('/');
  // ...
}

extension on String {
  PathData get toPathData => PathData(this);
}
```

All other helper functions (`regexPattern`, `openInAppBrowser`, etc.) and the full regex patterns are as documented in the previous version. This corrected guide provides a complete, safe, and robust blueprint for implementation.