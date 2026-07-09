import Combine
import Foundation

/// 面板共用的快照重载节拍。
///
/// 后台 LaunchAgent 约每 2 分钟写一次快照文件，但 app 面板原本只在
/// onAppear 时读一次——停留在页面上时数据不会动。各面板订阅这个节拍
/// 定期重读本地快照（纯文件读取，无网络请求），停留页面最多 10 秒
/// 内就能看到后台刷出的新数据。
let snapshotReloadTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
