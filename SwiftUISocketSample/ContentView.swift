//
//	ContentView.swift
//  SwiftUISocketSample
//
//  Created by Juan Mueller on 1/8/23.
//  For more, visit www.ajourneyforwisdom.com
//

import SwiftUI
import SocketIO

struct ContentView: View {
    var body: some View {
        ChatView()
    }
}

struct Message: Hashable {
    var username: String
    var text: String
    var id: UUID
}

struct ChatView: View {
    @State private var message: String = ""
    @State private var messages: [Message] = []
    @State private var username: String = ""
    @State private var users: [String:String] = [:]
    @State private var newUser: String = ""
    @State private var showUsernamePrompt: Bool = true
    @State private var isShowingNewUserAlert = false

    var body: some View {
        NavigationView {
            VStack {
                if showUsernamePrompt {
                    HStack {
                        TextField("Enter your username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: connect) {
                            Text("Connect")
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(messages, id: \.self) { message in
                            HStack {
                                if message.username == username {
                                    Text("Me:")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                } else {
                                    Text("\(message.username):")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                
                                Text(message.text)
                            }
                        }
                    }

                    HStack {
                        TextField("Enter a message", text: $message)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: sendMessage) {
                            Text("Send")
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Awesome Chat \(users.count > 0 ? "(\(users.count) connected)" : "")")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                ChatClient.shared.disconnect()
            }
            .alert("\(newUser) just joined the chat!",
                   isPresented: $isShowingNewUserAlert) {
                Button("OK", role: .cancel) {
                    isShowingNewUserAlert = false
                }
            }
        }
    }

    func connect() {
        ChatClient.shared.connect(username: username)
        ChatClient.shared.receiveMessage { username, text, id in
            self.receiveMessage(username: username, text: text, id: id)
        }
        ChatClient.shared.receiveNewUser { username, users in
            self.receiveNewUser(username: username, users: users)
        }
        showUsernamePrompt = false
    }

    func sendMessage() {
        ChatClient.shared.sendMessage(message)
        message = ""
    }

    func receiveMessage(username: String, text: String, id: UUID) {
        messages.append(Message(username: username, text: text, id: id))
    }
    
    func receiveNewUser(username: String, users: [String:String]) {
        self.users = users
        self.newUser = username
        
        self.isShowingNewUserAlert = self.username != username
    }
}

class ChatClient: NSObject {
    static let shared = ChatClient()

    var manager: SocketManager!
    var socket: SocketIOClient!
    var username: String!

    override init() {
        super.init()

        manager = SocketManager(socketURL: URL(string: "http://localhost:3000")!)
        socket = manager.defaultSocket
    }

    func connect(username: String) {
        self.username = username
        socket.connect(withPayload: ["username": username])
    }

    func disconnect() {
        socket.disconnect()
    }

    func sendMessage(_ message: String) {
        socket.emit("sendMessage", message)
    }
    
    func sendUsername(_ username: String) {
        socket.emit("sendUsername", username)
    }

    func receiveMessage(_ completion: @escaping (String, String, UUID) -> Void) {
        socket.on("receiveMessage") { data, _ in
            if let text = data[2] as? String,
               let id = data[0] as? String,
               let username = data[1] as? String {
                completion(username, text, UUID.init(uuidString: id) ?? UUID())
            }
        }
    }
    
    func receiveNewUser(_ completion: @escaping (String, [String:String]) -> Void) {
        socket.on("receiveNewUser") { data, _ in
            if let username = data[0] as? String,
               let users = data[1] as? [String:String] {
                completion(username, users)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
