#import "KDSceneDelegate.h"

#import "KDMainViewController.h"

@implementation KDSceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    KDMainViewController *mainViewController = [[KDMainViewController alloc] init];
    mainViewController.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.window.rootViewController = mainViewController;
    [self.window makeKeyAndVisible];
}

@end
