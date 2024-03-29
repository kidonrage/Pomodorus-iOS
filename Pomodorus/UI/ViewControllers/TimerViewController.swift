//
//  TimerViewController.swift
//  Pomodorus
//
//  Created by Vlad Eliseev on 21.08.2021.
//

import UIKit

final class TimerViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var sessionTypeLabel: UILabel!
    
    // MARK: - Public Properties
    var taskTitle: String!
    var workSessionStartTime: TimeInterval?
    var restSessionStartTime: TimeInterval?
    
    // MARK: - Private Properties
    private var progressLayer = CAShapeLayer()
    private var trackLayer = CAShapeLayer()
    
    private var timer: Timer?
    
    private var workSecondsElapsed: Double {
        guard let workSessionStartTime = self.workSessionStartTime else { return UserSettingsManager.shared.workSessionDuration }
        return Date().timeIntervalSince1970 - workSessionStartTime
    }
    private var restSecondsElapsed: Double {
        guard let restSessionStartTime = self.restSessionStartTime else { return 0 }
        return Date().timeIntervalSince1970 - restSessionStartTime
    }
    
    private var isResting = false {
        didSet {
            sessionTypeLabel.text = isResting ? "Rest" : "Work"
            progressLayer.strokeColor = isResting ? #colorLiteral(red: 0.4431372549, green: 1, blue: 0.5450980392, alpha: 1).cgColor : #colorLiteral(red: 0.9921568627, green: 0.3019607843, blue: 0.2941176471, alpha: 1).cgColor
        }
    }
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = taskTitle
        
        navigationItem.setHidesBackButton(true, animated: true)
        
        setupTimerProgressBar()
        
        if restSessionStartTime != nil {
            startRestTimer()
        } else {
            startWorkTimer()
        }
    }
    
    // MARK: - IBActions
    @IBAction func stopButtonTapped(_ sender: Any) {
        timer?.invalidate()
        
        let ac = UIAlertController(title: "Are You sure?", message: "Stopping the timer will delete your progress in this focus session", preferredStyle: .alert)
        
        ac.addAction(UIAlertAction(title: "Leave", style: .destructive, handler: { [weak self]  _ in
            self?.leave()
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            if self?.isResting ?? false {
                self?.continueRestTimer()
            } else {
                self?.continueWorkTimer()
            }
        }))
        
        present(ac, animated: true)
    }
    
    
    // MARK: - Private Methods
    private func leave() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UserSettingsManager.shared.removeStartedTask()
        UserSettingsManager.shared.removeRestedTask()
        workSessionStartTime = nil
        restSessionStartTime = nil
        navigationController?.popViewController(animated: true)
    }
    
    private func finishWorkSession() {
        self.timer?.invalidate()
        
        if let workSessionStartTime = self.workSessionStartTime {
            let task = Task(title: taskTitle, executionTimeStamp: workSessionStartTime)
            TasksManager.shared.saveTask(task)
        }
        
        UserSettingsManager.shared.removeStartedTask()
        workSessionStartTime = nil
        
        let ac = UIAlertController(title: "Yay! You've done it!", message: "It's time for the short rest now", preferredStyle: .alert)
        
        ac.addAction(UIAlertAction(title: "Rest", style: .default, handler: { [weak self]  _ in
            self?.startRestTimer()
        }))
        ac.addAction(UIAlertAction(title: "Leave", style: .cancel, handler: { [weak self] _ in
            self?.leave()
        }))
        
        present(ac, animated: true)
    }
    
    private func finishRestSession() {
        self.timer?.invalidate()
        
        UserSettingsManager.shared.removeRestedTask()
        restSessionStartTime = nil
        
        let ac = UIAlertController(title: "Resting is over!", message: "It's time for the next work session", preferredStyle: .alert)
        
        ac.addAction(UIAlertAction(title: "I'm ready", style: .default, handler: { [weak self]  _ in
            self?.startWorkTimer()
        }))
        ac.addAction(UIAlertAction(title: "Leave", style: .cancel, handler: { [weak self] _ in
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            self?.navigationController?.popViewController(animated: true)
        }))
        
        present(ac, animated: true)
    }
    
    private func checkRestTimer() {
        let remainingSeconds = (UserSettingsManager.shared.restSessionDuration - self.restSecondsElapsed).rounded()
        
        // Юзаем max чтобы не уходить в минус когда надолго сворачиваем аппку
        let minutes = max((remainingSeconds / 60).rounded(.down), 0)
        let seconds = max(remainingSeconds - minutes * 60, 0)
        self.timeLabel.text = String(format: "%02d:%02d", Int(minutes), Int(seconds))
        
        self.progressLayer.strokeEnd = CGFloat(self.restSecondsElapsed / UserSettingsManager.shared.restSessionDuration)
        
        if UserSettingsManager.shared.restSessionDuration - self.restSecondsElapsed <= 0 {
            self.finishRestSession()
        }
    }
    
    fileprivate func continueRestTimer() {
        checkRestTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            guard let `self` = self else { return }
            
            self.checkRestTimer()
        })
    }
    
    private func startRestTimer() {
        if  self.restSessionStartTime == nil {
            let updatedRestSessionStartTime = Date().timeIntervalSince1970
            restSessionStartTime = updatedRestSessionStartTime
            
            let content = UNMutableNotificationContent()
            content.title = "Rest session is finished!"
            content.body = "It's time for the work now. Open an app to start work session"
            content.sound = UNNotificationSound.default
            content.userInfo = ["task": taskTitle]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: UserSettingsManager.shared.restSessionDuration, repeats: false)
            
            let request = UNNotificationRequest(identifier: "restFinished", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                print(error?.localizedDescription)
            }
            
            let task = Task(title: taskTitle, executionTimeStamp: updatedRestSessionStartTime)
            UserSettingsManager.shared.saveRestedTask(task: task)
        }
        
        isResting = true
        
        continueRestTimer()
    }
    
    private func checkWorkTimer() {
        let remainingSeconds = (UserSettingsManager.shared.workSessionDuration - self.workSecondsElapsed).rounded()
        
        // Юзаем max чтобы не уходить в минус когда надолго сворачиваем аппку
        let minutes = max((remainingSeconds / 60).rounded(.down), 0)
        let seconds = max(remainingSeconds - minutes * 60, 0)
        self.timeLabel.text = String(format: "%02d:%02d", Int(minutes), Int(seconds))
        
        self.progressLayer.strokeEnd = CGFloat(self.workSecondsElapsed / UserSettingsManager.shared.workSessionDuration)
        
        if remainingSeconds <= 0 {
            self.finishWorkSession()
        }
    }
    
    fileprivate func continueWorkTimer() {
        checkWorkTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            guard let `self` = self else { return }
            
            self.checkWorkTimer()
        })
    }
    
    private func startWorkTimer() {
        if  self.workSessionStartTime == nil {
            let updatedWorkSessionStartTime = Date().timeIntervalSince1970
            workSessionStartTime = updatedWorkSessionStartTime
            
            let content = UNMutableNotificationContent()
            content.title = "Work session is finished!"
            content.body = "It's time for the short rest now. Open an app to start rest session"
            content.sound = UNNotificationSound.default
            content.userInfo = ["task": taskTitle]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: UserSettingsManager.shared.workSessionDuration, repeats: false)
            
            let request = UNNotificationRequest(identifier: "workFinished", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                print(error?.localizedDescription)
            }
            
            let task = Task(title: taskTitle, executionTimeStamp: updatedWorkSessionStartTime)
            UserSettingsManager.shared.saveStartedTask(task: task)
        }
        
        isResting = false
        
        continueWorkTimer()
    }
    
    private func setupTimerProgressBar() {
        let circlePath = UIBezierPath(arcCenter: .zero, radius: 100, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        
        // Add track layer
        trackLayer.path = circlePath.cgPath
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = #colorLiteral(red: 0.9607843137, green: 0.9607843137, blue: 0.9607843137, alpha: 1).cgColor
        trackLayer.lineWidth = 10.0
        trackLayer.strokeEnd = 1.0
        trackLayer.position = view.center
        
        view.layer.addSublayer(trackLayer)
        
        // Add progress layer
        progressLayer.path = circlePath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = 10.0
        progressLayer.strokeEnd = 0
        progressLayer.position = view.center
        progressLayer.transform = CATransform3DMakeRotation(-CGFloat.pi / 2, 0, 0, 1)
        
        view.layer.addSublayer(progressLayer)
    }

}
