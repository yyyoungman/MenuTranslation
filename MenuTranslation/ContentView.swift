//
//  ContentView.swift
//  MenuTranslation
//
//  Created by Limeng Ye on 2024/1/19.
//

import SwiftUI
import PhotosUI
import Vision
import Foundation

extension View {
    /// Usually you would pass  `@Environment(\.displayScale) var displayScale`
    @MainActor func asUIImage(scale displayScale: CGFloat = 1.0) -> UIImage {
        let renderer = ImageRenderer(content: self)

        renderer.scale = displayScale
        
        return renderer.uiImage!
    }
}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: nil)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return UIColor(red: CGFloat(bitmap[0]) / 255.0, green: CGFloat(bitmap[1]) / 255.0, blue: CGFloat(bitmap[2]) / 255.0, alpha: CGFloat(bitmap[3]) / 255.0)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

func searchImage(query: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
    let apiKey = "AIzaSyBV8Zn9wWiIJB_fgdJ8ynlbYL63Lsm1ApY"
    let searchEngineID = "b6e67c69b6ca44974"
    let urlString = "https://www.googleapis.com/customsearch/v1?key=\(apiKey)&cx=\(searchEngineID)&q=\(query)&searchType=image"
    
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
        return
    }
    
    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let items = json["items"] as? [[String: Any]],
                let firstItem = items.first,
                let link = firstItem["link"] as? String,
                let imageURL = URL(string: link),
                let imageData = try? Data(contentsOf: imageURL),
                let image = UIImage(data: imageData) {
                completion(.success(image))
            } else {
                completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    task.resume()
}

// open camera or select from photo library
// and do text recognition using API

struct ContentView: View {
    @State private var menuItem: PhotosPickerItem?
    @State public var menuUIImage: UIImage?
    // @State private var ocrImage: Image?
    @State private var recognizedImage: Image?
    // @State private var boundingRects: [CGRect] = []
    // @State private var textLoc = [String: CGRect]()
    @State private var textLoc = [(String, CGRect)]()
    // @State private var textLocArray = [(String, CGRect)]()
    let formatter = DateFormatter()
    
    var body: some View {
        VStack {
            PhotosPicker("Select menu", selection: $menuItem, matching: .images)
            
            recognizedImage?
                .resizable()
                .scaledToFit()
//                .frame(width: 300, height: 300)

            Button("Explain") {
                let dish = "Shrimp Remoulade"
                

                // // Usage:
                // searchImage(query: "shrimp remoulade") { result in
                //     switch result {
                //     case .success(let image):
                //         // Use the image here                        
                //         print("Image search successful")
                //     case .failure(let error):
                //         // Handle the error here
                //         print("Image search failed: \(error)")
                //     }
                // }
            }
        }
        .onChange(of: menuItem) {
            Task {
                // date format only includes seconds and milliseconds
                formatter.dateFormat = "ss.SSS"
                print("[time] photo selected", formatter.string(from: Date()))
                if let loaded = try? await menuItem?.loadTransferable(type: Image.self) {
                    print("[time] photo loaded", formatter.string(from: Date()))
                    let menuImage = loaded
                    recognizedImage = menuImage
                    menuUIImage = menuImage.asUIImage()
                    print("[time] menuImage.asUIImage", formatter.string(from: Date()))
                    // call recognizeText in background
                    Task {
                        recognizeText(image: menuUIImage!)
                    }
                    
//                    sendImageToServer(image: menuUIImage!)
//                    recognizeText(image: menuUIImage!)
                    // sendImageToServer(image: menuUIImage!)
                } else {
                    print("Failed")
                }
            }
        }
    }

    // function to recognize text from image
    func recognizeText(image: UIImage) {
        let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        request.recognitionLevel = .accurate
//        request.recognitionLanguages = ["en_US"]
//        request.recognitionLanguages = ["en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR", "zh-Hans", "zh-Hant", "yue-Hans", "yue-Hant", "ko-KR", "ja-JP", "ru-RU", "uk-UA", "th-TH", "vi-VT"]
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.03
        do {
            print("[time] ocr start", formatter.string(from: Date()))
            try requestHandler.perform([request])
        } catch {
            print(error)
        }
    }

    func splitArray(array: [String]) -> [[String]] {
        let shareSize = 10
        let arraySize = array.count
        let shareCount = Int(ceil(Double(arraySize) / Double(shareSize)))
        var arrayShares = [[String]]()
        for i in 0..<shareCount {
            let start = i * shareSize
            let end = min((i + 1) * shareSize, arraySize)
            arrayShares.append(Array(array[start..<end]))
        }
        return arrayShares
    }

    // function to handle the result of text recognition
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        print("[time] ocr finished", formatter.string(from: Date()))
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            fatalError("Received invalid observations")
        }

        // var recognizedStrings = observations.compactMap { observation in
        //     return observation.topCandidates(1).first?.string
        // }
        // // if any of the recognized strings is just numbers or symbols, remove it
        // recognizedStrings = recognizedStrings.filter { !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: $0)) }
        // print("OCR results: ", recognizedStrings)

        // get bounding boxes
        textLoc = observations.compactMap { observation in
            // Find the top observation.
            guard let candidate = observation.topCandidates(1).first else { return nil }

            // if candidate string contains only numbers and symbols, remove it
            if let range = candidate.string.range(of: "^[0-9\\.\\:\\$ ]+$", options: .regularExpression) {
                if range.lowerBound == candidate.string.startIndex && range.upperBound == candidate.string.endIndex {
                    return nil
                }
            }
//            if let range = candidate.string.range(of: regex, options: .regularExpression) {
//                if range.lowerBound == candidate.string.startIndex && range.upperBound == candidate.string.endIndex {
//                    return nil
//                }
//            }
            // let characterSet = CharacterSet.decimalDigits.union(CharacterSet.symbols)
            // if candidate.string.rangeOfCharacter(from: characterSet.inverted) == nil {
            //     return nil
            // }
            // if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: candidate.string)) {
            //     return nil
            // }
            
            // Find the bounding-box observation for the string range.
            let stringRange = candidate.string.startIndex..<candidate.string.endIndex
            let boxObservation = try? candidate.boundingBox(for: stringRange)
            
            // Get the normalized CGRect value.
            var boundingBox = boxObservation?.boundingBox ?? .zero

            // flip y coordinate of bounding box
            boundingBox.origin.y = 1 - boundingBox.origin.y - boundingBox.size.height            
            // Convert the rectangle from normalized coordinates to image coordinates.
            let rect = VNImageRectForNormalizedRect(boundingBox,
                                                Int(menuUIImage!.size.width),
                                                Int(menuUIImage!.size.height))
            
            // Return the string and its corresponding bounding box.
            return (candidate.string, rect)
        }

        // // generate dictionary of text and bounding boxes
        // for i in 0..<recognizedStrings.count {
        //     textLoc[recognizedStrings[i]] = boundingRects[i]
        // }

        // get just the string array from textLoc
        let recognizedStrings = textLoc.map { (text, _) in text }

        // divide text into n shares, and send each share to server
        // sendOCRTextToServer(textOCR: recognizedStrings)
        let textOCRShares = splitArray(array:recognizedStrings)
        for share in textOCRShares {
            sendOCRTextToServer(textOCR: share)
        }

        // draw bounding boxes to recognized image
        let renderer = UIGraphicsImageRenderer(size: menuUIImage!.size)
        let renderedImage = renderer.image { context in
            menuUIImage!.draw(at: .zero)
            context.cgContext.setStrokeColor(UIColor.red.cgColor)
            context.cgContext.setLineWidth(2)
            textLoc.forEach { (_, rect) in
                context.cgContext.addRect(rect)
                context.cgContext.drawPath(using: .stroke)
            }
        }
        print("[time] ocr text rendered", formatter.string(from: Date()))
        self.recognizedImage = Image(uiImage: renderedImage)
    }

    func sendOCRTextToServer(textOCR: [String]) {
        let jsonData = try? JSONSerialization.data(withJSONObject: textOCR)
//        let url = URL(string: "https://menu.ailisteners.com/v1")!
        let url = URL(string: "http://localhost:8787")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("CF_TOKEN", forHTTPHeaderField: "Authorization") // cloudflare
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // request.timeoutInterval = 120 // Increase timeout to 120 seconds
        print("[time] request start", formatter.string(from: Date()))
        URLSession.shared.dataTask(with: request) { data, response, error in
            print("[time] request received", formatter.string(from: Date()))
            if let error = error {
                print("Error: \(error)")
            }
            if let data = data {
                print(String(data: data, encoding: .utf8)!)
                let json = try? JSONSerialization.jsonObject(with: data, options: [])
                if let translation = json as? [String: String] {
                    let translationRect = matchText(translation: translation, textOCR: textLoc)
                    renderText(text: translationRect)
                }

            }
        }.resume()
    }
//
//    func matchTextToText(translation: [String: String], textOCR: [String]) -> [(CGRect, String)] {
//        for tr in translation {
//            print(tr)
//        }
//        return [(CGRect, String)]()
//    }

//    func sendImageToServer(image: UIImage) {
//        // mock json
//        let json = try? JSONSerialization.jsonObject(with: brunchData.data(using: .utf8)!, options: [])
//        if let translation = json as? [String: String] {
//            let translationRect = matchText(translation: translation, textOCR: textLoc)
//            renderText(text: translationRect)
//        }
//        return
//
//        let resizedImage = resizeImage(image: image)
//        print("Image size: \(resizedImage.size)")
//        let imageData = resizedImage.jpegData(compressionQuality: 0.5)
//        // let url = URL(string: "https://menu.ailisteners.com/v1")!
//        let url = URL(string: "http://localhost:8787")!
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.httpBody = imageData
//        request.addValue("CF_TOKEN", forHTTPHeaderField: "Authorization") // cloudflare
//        request.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
//        request.timeoutInterval = 120 // Increase timeout to 120 seconds
//        URLSession.shared.dataTask(with: request) { data, response, error in
////            print("Response: \(String(describing: response))")
//            if let error = error {
//                print("Error: \(error)")
//            }
//            if let data = data {
//                print(String(data: data, encoding: .utf8)!)
//                let json = try? JSONSerialization.jsonObject(with: data, options: [])
//                if let translation = json as? [String: String] {
//                    let translationRect = matchText(translation: translation, textOCR: textLoc)
//                    renderText(text: translationRect)
//                }
//
//            }
//        }.resume()
//    }
//
//    func resizeImage(image: UIImage) -> UIImage {
//        // resize image to less than 1024, keep aspect ratio
//        let maxSize: CGFloat = 1024
//        var width = image.size.width
//        var height = image.size.height
//        if width > maxSize || height > maxSize {
//            if width > height {
//                let ratio = width / maxSize
//                width = maxSize
//                height = CGFloat(Int(round(height / ratio / 4)) * 4) // round to nearest 4
//            } else {
//                let ratio = height / maxSize
//                height = maxSize
//                width = CGFloat(Int(round(width / ratio / 4)) * 4) // round to nearest 4
//            }
//        }
//        let size = CGSize(width: width, height: height)
//        let renderer = UIGraphicsImageRenderer(size: size)
//        let resizedImage = renderer.image { context in
//            image.draw(in: CGRect(origin: .zero, size: size))
//        }
//        return resizedImage
//    }

    func matchText(translation: Dictionary<String, String>, textOCR: [(String, CGRect)]) -> [(CGRect, String)] {
        // do a fuzzy match between textOCR and translation's keys
        // var translationRect = [CGRect: String]()
        // using an array containing rect and string, instead of dictionary, because text might be repetitive
        var translationRect = [(CGRect, String)]()
        for (k_o, loc) in textOCR {
            for (k_t, v_t) in translation {
                if fuzzyMatch(k_o, k_t) {
                    translationRect.append((loc, v_t))
                    break
                }
            }
        }
        return translationRect
    }
    
    // function to fuzzy match two strings, if 50% of the words match, return true
    func fuzzyMatch(_ str1: String, _ str2: String) -> Bool {
        // convert to lowercase
        let str1_low = str1.lowercased().components(separatedBy: " ")
        let str2_low = str2.lowercased().components(separatedBy: " ")
        
        // remove marks and symbols from words
        let marks = CharacterSet(charactersIn: ".,:;!?/|()[]{}&^%$#@!~`‘’“”\'\"\\")
        let words1 = str1_low.map { $0.components(separatedBy: marks).joined() }
        let words2 = str2_low.map { $0.components(separatedBy: marks).joined() }

        // if words counts differ more than one, return false
        if abs(words1.count - words2.count) > 1 {
            return false
        }

        var count = 0
        for word1 in words1 {
            for word2 in words2 {
                if word1 == word2 {
                    count += 1
                }
            }
        }
        let threshold = 0.9
        var validCount = Int(round(Double(words1.count) * threshold))
        if validCount == 0 {
            validCount = 1
        }
        if count >= validCount {
            print("matching", str1, str2)
            return true
        } else {
            return false
        }
    }
    
    func renderText(text: [(CGRect, String)]) {
        DispatchQueue.main.async {
            renderTextOnMain(text:text)
        }
    }

    @MainActor func renderTextOnMain(text: [(CGRect, String)]) {
        let currentImage = recognizedImage.asUIImage()
        let renderer = UIGraphicsImageRenderer(size: currentImage.size)
        let renderedImage = renderer.image { context in
            currentImage.draw(at: .zero)

            context.cgContext.setStrokeColor(UIColor.red.cgColor)
            context.cgContext.setLineWidth(2)
            text.forEach { (loc, t) in
                context.cgContext.addRect(loc)
                context.cgContext.drawPath(using: .stroke)

                // get color of background
                let cgImage = currentImage.cgImage!
                let expandingRatioX: CGFloat = 0.02
                let expandingRatioY: CGFloat = 0.06
                let expandedLoc = CGRect(x: loc.origin.x - loc.width * expandingRatioX,
                                         y: loc.origin.y - loc.height * expandingRatioY,
                                         width: loc.width * (1 + 2 * expandingRatioX),
                                         height: loc.height * (1 + 2 * expandingRatioY))
                guard let croppedCGImage = cgImage.cropping(to: expandedLoc) else {
                    return
                }
                let croppedImage = UIImage(cgImage: croppedCGImage)
                let avgColor = croppedImage.averageColor!
                let borderColor = getBorderColor(image: croppedImage)
                // set fill color to average color
                context.cgContext.setFillColor(borderColor.cgColor)
                // context.cgContext.setAlpha(0.5)
                context.cgContext.fill(loc)

                // draw text
                let textRect = CGRect(x: loc.origin.x, y: loc.origin.y, width: loc.width*1.3, height: loc.height)
                // set text size based on bounding box size
                let fontSize = loc.height * 0.8

                // make text bolder
                let textFontAttributes = [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: fontSize),
                    NSAttributedString.Key.foregroundColor: UIColor.red,
                ]
                
                let textString = NSAttributedString(string: t, attributes: textFontAttributes)
                textString.draw(in: textRect)
            }
        }
        print("[time] translation text rendered", formatter.string(from: Date()))
        self.recognizedImage = Image(uiImage: renderedImage)
    }

    func getBorderColor(image: UIImage) -> UIColor {
        // get average color of bounding box
        let cgImage = image.cgImage!
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixelBuffer = context.data!
        let pixel = pixelBuffer.load(fromByteOffset: 0, as: UInt32.self)
        let r = CGFloat((pixel >> 0) & 0xFF) / 255.0
        let g = CGFloat((pixel >> 8) & 0xFF) / 255.0
        let b = CGFloat((pixel >> 16) & 0xFF) / 255.0
        let a = CGFloat((pixel >> 24) & 0xFF) / 255.0
        let color = UIColor(red: r, green: g, blue: b, alpha: a)
        return color
    }

    let brunchData = """
        {
        "HOURS": "营业时间",
        "SAT 11AM - 3PM": "周六 上午11点 - 下午3点",
        "SUN 10AM - 3PM": "周日 上午10点 - 下午3点",
        "CYO OMELETTE": "自选欧姆蛋",
        "THREE WHIPPED EGGS": "三个打发的鸡蛋",
        "with choice of three items below,": "以下三种食材任选，",
        "home fries and toast": "家乡风味炸土豆和吐司",
        "additional items +1/ea": "额外食材 每项加1美元",
        "OPTIONS": "选项",
        "HAM, BACON, TURKEY, MUSHROOMS,": "火腿、培根、火鸡、蘑菇，",
        "GREEN PEPPER, RED PEPPER, BABY SPINACH,": "绿椒、红椒、婴儿菠菜，",
        "JALAPENOS, ONION, TOMATO, BLACK OLIVES,": "墨西哥胡椒、洋葱、西红柿、黑橄榄，",
        "SUN-DRIED TOMOTOES, BANANA PEPPERS,": "晒干的西红柿、香蕉椒，",
        "CHEDDAR, PEPPERJACK, PROVOLONE,": "切达干酪、辣椒干酪、普罗沃洛尼干酪，",
        "MOZZARELLA, AMERICAN, GOUDA, FETA": "莫扎里拉、美国干酪、古达干酪、羊乳酪",
        "A LA CARTE": "单点菜单",
        "1 BELGIUM WAFFLE": "1个比利时华夫饼",
        "2 PANCAKES": "2个煎饼",
        "TATER KEGS": "土豆桶",
        "BACON": "培根",
        "BREAKFAST SAUSAGE": "早餐香肠",
        "2 EGGS": "2个鸡蛋",
        "HOME FRIES": "家乡风味炸土豆",
        "FRESH FRUIT": "新鲜水果",
        "TOAST OR BAGEL": "吐司或百吉饼",
        "ENGLISH MUFFIN OR BISCUIT": "英式松饼或饼干",
        "SIGNATURE": "招牌",
        "IVY’S CHICKEN & WAFFLES": "常春藤鸡肉与华夫饼",
        "served with home fries": "配上家乡风味炸土豆",
        "STERN’S BIG STACK": "斯特恩的大叠饼",
        "3 pancakes, bacon, or sausage & home fries": "3个煎饼、培根或香肠和家乡风味炸土豆",
        "THE BAG LADY": "包包女士",
        "choice of 2 pancakes or 2 biscuits or English muffins": "2个煎饼、2个饼干或2个英式松饼任选",
        "bacon, sausage, home fries & two eggs": "培根、香肠、家乡风味炸土豆和两个鸡蛋",
        "IVY’S AVOCADO TOAST": "常春藤鳄梨吐司",
        "Served with 2 poached eggs & bacon or sausage": "配2个水煮鸡蛋和培根或香肠",
        "HANGOVER SANDWICH": "宿醉三明治",
        "choice of biscuit, English muffin, bagel or toast": "饼干、英式松饼、百吉饼或吐司任选",
        "choice of cheese with bacon, ham & sausage": "配有选择的奶酪、培根、火腿和香肠",
        "served with home fries": "配上家乡风味炸土豆",
        "JEFF’S BISCUITS & GRAVY": "杰夫的饼干与肉汁",
        "buttermilk biscuits with homemade sausage gravy": "配自制香肠肉浆的白脱牛奶饼干",
        "2 eggs on top & a side of bacon": "上面2个鸡蛋和一份培根",
        "IVY’S EGGS BENEDICT": "常春藤荷兰酱鸡蛋",
        "served with bacon or sausage & home fries": "配培根或香肠与家乡风味炸土豆",
        "UNCLE SAM’S FRENCH TOAST": "山姆大叔的法式吐司",
        "Cinnamon style with brioche bread": "配肉桂风味的布里欧面包",
        "served with bacon or sausage & 2 eggs": "配培根或香肠和2个鸡蛋",
        "JOE’S STEAK N EGGS": "乔的牛排与鸡蛋",
        "8 oz. baseball sirloin, 2 eggs & cup of fruit": "8盎司棒球牛排、2个鸡蛋和一杯水果",
        "served with home fries": "配上家乡风味炸土豆",
        "Rest in peace Joe": "安息吧，乔",
        "JUNE’S BIG GAY SKILLET": "琼的大同志煎锅",
        "Corn beef hash with egg, sausage, cheese &": "玉米牛肉碎与鸡蛋、香肠、奶酪和",
        "choice of bread": "选择的面包"
        }
        """
}

#Preview {
    ContentView(menuUIImage: nil)
}
