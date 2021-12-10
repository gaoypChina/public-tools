//
//  App.swift
//  Runner
//
//  Created by 虚幻 on 2021/11/28.
//

import Foundation
import FlutterMacOS

public extension String {
    func isIncludeChinese() -> Bool {
        for ch in self.unicodeScalars {
            // 中文字符范围：0x4e00 ~ 0x9fff
            if (0x4e00 < ch.value  && ch.value < 0x9fff) {
                return true
            }
        }
        return false
    }
    
    func transformToPinyin() -> String {
        let stringRef = NSMutableString(string: self) as CFMutableString
        // 转换为带音标的拼音
        CFStringTransform(stringRef,nil, kCFStringTransformToLatin, false);
        // 去掉音标
        CFStringTransform(stringRef, nil, kCFStringTransformStripCombiningMarks, false);
        let pinyin = stringRef as String;
        return pinyin
    }

}

public class AppService: NSObject, PBCService {
    public func getInstalledApplicationList(completion: @escaping ([PBCInstalledApplication]?, FlutterError?) -> Void) {
        let query = NSMetadataQuery()
        query.stop()
        let predicate = NSPredicate(format: "kMDItemContentType == 'com.apple.application-bundle'")
        query.predicate = predicate
        query.searchScopes = ["/Applications", "/System/Applications", "/System/Library/CoreServices/Applications"]
        var observer: Any?
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil, queue: nil) { (notification) in
            var list = [PBCInstalledApplication]()
            for i in 0 ..< query.resultCount {
                guard let item = query.result(at: i) as? NSMetadataItem else { continue }
                let name = (item.value(forAttribute: kMDItemDisplayName as String) as! String)
                    .replacingOccurrences(of: ".app", with: "")
                let path = item.value(forAttribute: kMDItemPath as String) as! String;
                let bundlePath = path + "/Contents/Info.plist"
                let dict = NSDictionary(contentsOfFile: bundlePath)!
                var iconPath = ""
                if let iconName = dict["CFBundleIconFile"] {
                    iconPath = path + "/Contents/Resources/" + (iconName as! String) + ".icns"
                }
                if let iconName = dict["CFBundleIconName"] {
                    iconPath = path + "/Contents/Resources/" + (iconName as! String) + ".icns"
                }
                if !FileManager.default.fileExists(atPath: iconPath) {
                    iconPath = ""
                }
                let app = PBCInstalledApplication()
                app.name = name
                app.path = path
                app.icon = iconPath
                app.pinyin = name.transformToPinyin()
                list.append(app)
            }
            NotificationCenter.default.removeObserver(observer!)
            completion(list, nil);
        }
        query.start()
    }
    public func hideAppWithError(_ error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
        NSApp.hide(nil)
    }
}
