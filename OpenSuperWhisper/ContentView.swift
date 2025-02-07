//
//  ContentView.swift
//  OpenSuperWhisper
//
//  Created by user on 05.02.2025.
//

import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var settings = Settings()
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var isSettingsPresented = false
    
    var body: some View {
        NavigationView {
            VStack {
                if !permissionsManager.isMicrophonePermissionGranted || !permissionsManager.isAccessibilityPermissionGranted {
                    PermissionsView(permissionsManager: permissionsManager)
                } else {
                    List {
                        ForEach(audioRecorder.recordings, id: \.self) { recording in
                            RecordingRow(url: recording, audioRecorder: audioRecorder, settings: settings)
                        }
                    }
                    
                    HStack {
                        Text("Recording Shortcut: \(settings.recordingShortcut.description)")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            isSettingsPresented.toggle()
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                        }
                    }
                    .padding()
                    
                    Button(action: {
                        audioRecorder.startRecording()
                    }) {
                        Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.system(size: 64))
                            .foregroundColor(audioRecorder.isRecording ? .red : .accentColor)
                    }
                    .padding()
                }
            }
            .navigationTitle("Audio Recorder")
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView(settings: settings)
            }
        }
        .onAppear {
            if UserDefaults.standard.string(forKey: "selectedModelPath") == nil {
                // Set default model on first launch
                if let defaultModel = WhisperModelManager.shared.getAvailableModels().first {
                    UserDefaults.standard.set(defaultModel.path, forKey: "selectedModelPath")
                }
            }
        }
    }
}

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Required Permissions")
                .font(.title)
                .padding()
            
            PermissionRow(
                isGranted: permissionsManager.isMicrophonePermissionGranted,
                title: "Microphone Access",
                description: "Required for audio recording",
                action: { permissionsManager.openSystemPreferences(for: .microphone) }
            )
            
            PermissionRow(
                isGranted: permissionsManager.isAccessibilityPermissionGranted,
                title: "Accessibility Access",
                description: "Required for global keyboard shortcuts",
                action: { permissionsManager.openSystemPreferences(for: .accessibility) }
            )
            
            Spacer()
        }
        .padding()
    }
}

struct PermissionRow: View {
    let isGranted: Bool
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isGranted ? .green : .red)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if !isGranted {
                    Button("Grant Access") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct RecordingRow: View {
    let url: URL
    let audioRecorder: AudioRecorder
    let settings: Settings
    @StateObject private var transcriptionService = TranscriptionService()
    @State private var showTranscription = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(url.lastPathComponent)
                
                Spacer()
                
                Button(action: {
                    audioRecorder.playRecording(url: url)
                }) {
                    Image(systemName: "play.circle")
                        .font(.title2)
                }
                
                Button(action: {
                    Task {
                        do {
                            _ = try await transcriptionService.transcribeAudio(url: url, settings: settings)
                            showTranscription = true
                        } catch {
                            print("Transcription failed: \(error)")
                        }
                    }
                }) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(transcriptionService.isTranscribing)
                
                Button(action: {
                    audioRecorder.deleteRecording(url: url)
                }) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            
            if transcriptionService.isTranscribing {
                ProgressView("Transcribing...")
                    .padding(.vertical, 4)
            }
            
            if !transcriptionService.transcribedText.isEmpty {
                TranscriptionView(transcribedText: transcriptionService.transcribedText, isExpanded: $showTranscription)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TranscriptionView: View {
    let transcribedText: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Transcription")
                    .font(.headline)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                ScrollView {
                    Text(transcribedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
