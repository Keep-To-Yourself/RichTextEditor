import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootVC = AppViewController()
        window?.rootViewController = rootVC
        window?.makeKeyAndVisible()
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // 应用即将进入非活动状态
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // 应用进入后台
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // 应用即将回到前台
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 应用变为活动状态
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // 应用即将终止
    }
}
