import SwiftUI
import AVFoundation
import WebKit
import Combine
import WhatsNewKit

// 主視圖 ContentView
struct ContentView: View {
    // MARK: - 狀態變數
    @State private var showSettings = false
    @State private var inputImage: UIImage?
    @State private var outputText: String = "準備中..."
    @State private var isProcessing: Bool = false
    @State private var isAutoProcessingEnabled: Bool = false
    @State private var isPresented: Bool = true
    @State private var predictedLabels: [Int: String]? = nil
    @State private var currentTask: Task?
    @State private var taskIndex: Int = 0
    @State private var countdown: Int = 0 // 倒數計時變數
    @State private var isCountingDown: Bool = false // 控制倒數狀態
    @State private var taskCompleted: Bool = false // 控制任務完成狀態
    @State private var timerCancellable: AnyCancellable?
    @State private var isCooldown: Bool = false // 控制冷卻狀態

    // 定義自動處理的計時器
    let autoProcessTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // 定義任務列表
    @State private var tasks: [Task] = [
        Task(
            name: "頭部向左轉",
            expectedConditions: [1: "left", 4: "turn"],
            duration: 4,
            modelName: "facing-model",
            icon: "arrowshape.left.fill",
            indexToLabelMap: [0: "front", 1: "left", 2: "right", 3: "tilt", 4: "turn"],
            multipliers: ["front": 1.4]
        ),
        Task(
            name: "頭部回正",
            expectedConditions: [0: "front"],
            duration: 4,
            modelName: "facing-model",
            icon: "face.smiling.inverse",
            indexToLabelMap: [0: "front", 1: "left", 2: "right", 3: "tilt", 4: "turn"],
            multipliers: ["front": 1.5]
        ),
        Task(
            name: "頭部向右轉",
            expectedConditions: [2: "right", 4: "turn"],
            duration: 4,
            modelName: "facing-model",
            icon: "arrowshape.right.fill",
            indexToLabelMap: [0: "front", 1: "left", 2: "right", 3: "tilt", 4: "turn"],
            multipliers: ["front": 1.3]
        ),
        Task(
            name: "向上看",
            expectedConditions: [7: "top"],
            duration: 4,
            modelName: "facing-model",
            icon: "arrow.up.circle.fill",
            indexToLabelMap: [5: "down", 6: "unknown", 7: "top"],
            multipliers: ["top": 1.4]
        )
    ]

    @StateObject var webViewModel = WebViewModel()

    // 定義 `WhatsNew` 資料
    var whatsNew: WhatsNew = WhatsNew(
        title: "珊迪的新冒險 🐿️🏄‍♀️",
        features: [
            .init(
                image: .init(systemName: "camera.fill", foregroundColor: .blue),
                title: "即時動作偵測",
                subtitle: "使用相機獲取即時回饋，就像珊迪的高科技套裝一樣！"
            ),
            .init(
                image: .init(systemName: "timer", foregroundColor: .green),
                title: "清脆又大聲的倒數",
                subtitle: "清脆又大聲的倒數讓你沒看著螢幕也知道自己做對了！"
            ),
            .init(
                image: .init(systemName: "list.bullet.rectangle.portrait", foregroundColor: .purple),
                title: "清晰可見的步驟",
                subtitle: "保持你健康的秘訣都清清楚楚的寫在螢幕上"
            ),
            .init(
                image: .init(systemName: "person.2.fill", foregroundColor: .orange),
                title: "大家一起來保持健康",
                subtitle: "和你的家人朋友們一起努力保持健康吧！"
            )
        ],
        primaryAction: WhatsNew.PrimaryAction(
            title: "開始吧！",
            backgroundColor: .accentColor,
            foregroundColor: .white,
            hapticFeedback: .notification(.success),
            onDismiss: {
                print("探索了珊迪的新功能！")
            }
        )
    )

    // 控制兩個不同的 sheet
    @State private var isWhatsNewPresented = true // 控制 WhatsNewSheet 的顯示狀態
    @State private var isBottomSheetPresented = false // 控制 BottomSheet 的顯示狀態

    // 環境變數，用於檢測裝置和尺寸類型
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var deviceOrientation = UIDevice.current.orientation

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                    // iPad 橫向模式，使用 HStack 佈局
                    ZStack {
                        HStack(spacing: 0) {
                            ZStack {
                                // 相機背景視圖
                                CameraView(capturedImage: $inputImage)
                                    .edgesIgnoringSafeArea(.all)
                                    .onAppear {
                                        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                                    }
                                    .onDisappear {
                                        UIDevice.current.endGeneratingDeviceOrientationNotifications()
                                    }
                                    .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                                        deviceOrientation = UIDevice.current.orientation
                                    }

                                // 倒數計時大字顯示
                                if isCountingDown && countdown > 0 {
                                    Text("\(countdown)")
                                        .font(.system(size: 100, weight: .bold))
                                        .foregroundColor(.white)
                                        .animation(.easeInOut, value: countdown)
                                        .transition(.opacity)
                                }
                            }
                            .frame(width: geometry.size.width * 0.6)

                            Spacer()
                        }

                        // 右側的側邊欄，添加間距和圓角
                        SideSheet(
                            isPresented: $isPresented,
                            outputText: $outputText,
                            isAutoProcessingEnabled: $isAutoProcessingEnabled,
                            isProcessing: $isProcessing,
                            inputImage: $inputImage,
                            tasks: $tasks,
                            currentTask: $currentTask,
                            taskIndex: $taskIndex,
                            predictedLabels: $predictedLabels,
                            taskCompleted: $taskCompleted,
                            countdown: $countdown,
                            isCountingDown: $isCountingDown
                        )
                        .frame(width: geometry.size.width * 0.35)
                        .padding(.trailing, 16)
                        .padding(.leading, geometry.size.width * 0.65 + 16)
                        .padding(.vertical, 16)
                    }
                } else {
                    // iPhone 或直向模式，使用原始佈局
                    ZStack {
                        // 相機背景視圖
                        CameraView(capturedImage: $inputImage)
                            .edgesIgnoringSafeArea(.all)

                        // 倒數計時大字顯示
                        if isCountingDown && countdown > 0 {
                            Text("\(countdown)")
                                .font(.system(size: 100, weight: .bold))
                                .foregroundColor(.white)
                                .animation(.easeInOut, value: countdown)
                                .transition(.opacity)
                        }

                        // 右上角的設定按鈕
                        VStack {
                            HStack {
                                Spacer()
                                NavigationLink(destination: SettingsView(), isActive: $showSettings) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
            .onAppear {
                // 初始化當前任務
                if tasks.indices.contains(taskIndex) {
                    currentTask = tasks[taskIndex]
                }

                // 註冊通知
                NotificationCenter.default.addObserver(forName: .taskConditionMet, object: nil, queue: .main) { notification in
                    if let taskName = notification.object as? String, taskName == currentTask?.name {
                        handleTaskConditionMet()
                    }
                }

                NotificationCenter.default.addObserver(forName: .taskConditionNotMet, object: nil, queue: .main) { _ in
                    handleTaskConditionNotMet()
                }

                // 設置倒數計時器
                timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        if isCountingDown {
                            if countdown > 0 {
                                countdown -= 1
                                outputText = "倒數: \(countdown)秒"
                                print("倒數: \(countdown)")
                                playTickSound()
                            }
                            if countdown == 0 && isCountingDown {
                                isCountingDown = false
                                taskCompleted = true
                                outputText = "任務完成！"
                                playSuccessSound()

                                // 開始冷卻期
                                isCooldown = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    isCooldown = false
                                    moveToNextTask()
                                }
                            }
                        }
                    }
            }
            .onReceive(autoProcessTimer) { _ in
                if isAutoProcessingEnabled && !isProcessing && !isCooldown && inputImage != nil {
                    isProcessing = true
                    currentTask = tasks[taskIndex]
                    print("定時器觸發，開始自動處理圖像")
                }
            }
            .onDisappear {
                // 移除通知
                NotificationCenter.default.removeObserver(self)
                // 取消倒數計時器
                timerCancellable?.cancel()
            }
            // 先呈現 WhatsNewSheet
            .sheet(isPresented: $isWhatsNewPresented) {
                WhatsNewView(whatsNew: whatsNew)
                    .onDisappear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if UIDevice.current.userInterfaceIdiom != .pad {
                                isBottomSheetPresented = true
                            } else {
                                isBottomSheetPresented = false // 確保在 iPad 上不顯示 BottomSheet
                            }
                        }
                    }
            }
            // 當 WhatsNewSheet 被關閉後，呈現 BottomSheet（僅在非 iPad 上）
            .sheet(isPresented: $isBottomSheetPresented) {
                if UIDevice.current.userInterfaceIdiom != .pad {
                    BottomSheet(
                        isPresented: $isPresented,
                        outputText: $outputText,
                        isAutoProcessingEnabled: $isAutoProcessingEnabled,
                        isProcessing: $isProcessing,
                        inputImage: $inputImage,
                        tasks: $tasks,
                        currentTask: $currentTask,
                        taskIndex: $taskIndex,
                        predictedLabels: $predictedLabels,
                        taskCompleted: $taskCompleted,
                        countdown: $countdown,
                        isCountingDown: $isCountingDown
                    )
                    .interactiveDismissDisabled()
                    .presentationDetents([.fraction(0.4), .fraction(0.5)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(36)
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.4)))
                }
            }
            // 隱藏的 WebViewContainer
            WebViewContainer(
                inputImage: $inputImage,
                outputText: $outputText,
                isProcessing: $isProcessing,
                predictedLabels: $predictedLabels,
                currentTask: $currentTask,
                tasks: $tasks
            )
            .frame(width: 0, height: 0)
        }
        .environmentObject(webViewModel)
        // 監聽 showSettings 的變化來控制 BottomSheet
        .onChange(of: showSettings) { newValue in
            if newValue {
                // SettingsView 被打開，收合 BottomSheet
                isBottomSheetPresented = false
            } else {
                // SettingsView 被關閉，展開 BottomSheet（僅在非 iPad 上）
                if UIDevice.current.userInterfaceIdiom != .pad {
                    isBottomSheetPresented = true
                }
            }
        }
    }

    // MARK: - 任務處理函數
    func handleTaskConditionMet() {
        print("條件達成: \(currentTask?.name ?? "未知任務")")
        if !isCountingDown && !isCooldown {
            startCountdown()
        }
    }

    func handleTaskConditionNotMet() {
        print("條件未達成")
        if isCountingDown {
            pauseCountdown()
        }
        outputText = "條件未達成"
    }

    func startCountdown() {
        isCountingDown = true
        countdown = currentTask?.duration ?? 4
        taskCompleted = false
        outputText = "倒數: \(countdown)秒"
    }

    func pauseCountdown() {
        isCountingDown = false
    }

    func moveToNextTask() {
        withAnimation(.easeInOut(duration: 0.5)) {
            taskIndex += 1
            if taskIndex >= tasks.count {
                taskIndex = 0
            }

            if tasks.indices.contains(taskIndex) {
                currentTask = tasks[taskIndex]
                taskCompleted = false
                countdown = 0
                isCountingDown = false
                outputText = "準備下一個任務"
            }
        }
    }

    func playSuccessSound() {
        AudioServicesPlaySystemSound(1057) // 成功音效
    }

    func playTickSound() {
        AudioServicesPlaySystemSound(1103) // 倒數計時音效
    }
}

// MARK: - BottomSheet View
struct BottomSheet: View {
    @Binding var isPresented: Bool
    @Binding var outputText: String
    @Binding var isAutoProcessingEnabled: Bool
    @Binding var isProcessing: Bool
    @Binding var inputImage: UIImage?
    @Binding var tasks: [Task]
    @Binding var currentTask: Task?
    @Binding var taskIndex: Int
    @Binding var predictedLabels: [Int: String]? // 綁定預測標籤
    @Binding var taskCompleted: Bool // 綁定任務完成狀態
    @Binding var countdown: Int // 綁定倒數計時
    @Binding var isCountingDown: Bool // 綁定倒數狀態

    @Environment(\.colorScheme) var colorScheme
    @State private var isFavorite = false // 用來觸發動畫效果

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(colorScheme == .dark ? .white : .black)
                            .opacity(0.1)
                        Button {
                            withAnimation {
                                isFavorite.toggle()
                            }
                        } label: {
                            Image(systemName: currentTask?.icon ?? "questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .padding()
                        }
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .padding(.trailing, 6)
                    .padding(.leading, 24)

                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(colorScheme == .dark ? .white : .black)
                            .opacity(0.1)

                        Text(taskCompleted ? "任務完成！" : outputText)
                            .font(.system(size: 24))
                            .fontWeight(.heavy)
                            .foregroundColor(taskCompleted ? .green : (colorScheme == .dark ? .white : .black))
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 24)
                }

                HStack {
                    ForEach(taskIndex..<min(taskIndex + 2, tasks.count), id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(taskCompleted && index == taskIndex ? .green : (colorScheme == .dark ? .white : .black))
                                .opacity(0.1)
                                .frame(height: 50)
                            Text(tasks[index].name)
                                .font(.system(size: 18))
                                .fontWeight(.medium)
                                .foregroundColor(taskCompleted && index == taskIndex ? .green : (colorScheme == .dark ? .white : .black))
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                HStack {
                    AnimatedButton(
                        text: isAutoProcessingEnabled ? "自動偵測關閉" : "自動偵測開啟",
                        action: {
                            isAutoProcessingEnabled.toggle()
                        },
                        lightBackgroundColor: .black,
                        darkBackgroundColor: .white,
                        foregroundColor: .white,
                        cornerRadius: 50,
                        horizontalPadding: 20,
                        verticalPadding: 16
                    )
                }
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .padding(.top, 24)
            .background(
                RoundedRectangle(cornerRadius: 36)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white)
                    .shadow(radius: 10)
            )
            .ignoresSafeArea()
        }
    }
}


// MARK: - Preview
#Preview{
    ContentView()
}
