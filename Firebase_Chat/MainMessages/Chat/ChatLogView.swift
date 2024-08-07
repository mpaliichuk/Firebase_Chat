import SwiftUI
import Firebase

struct ChatMessage: Identifiable {
    var id: String { documentId }
    let documentId: String
    let fromId, toId, text: String
    var likes: [String]
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data["fromId"] as? String ?? ""
        self.toId = data["toId"] as? String ?? ""
        self.text = data["text"] as? String ?? ""
        self.likes = data["likes"] as? [String] ?? []
    }
}

struct DescriptionPlaceHolder: View {
    var body: some View {
        HStack {
            Text("Enter message...")
                .foregroundColor(Color.gray)
                .padding(.leading, 8)
        }
        .opacity(0.5)
    }
}

class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    @Published var count = 0
    
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        fetchMessages()
    }
    
    func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach { change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(ChatMessage(documentId: change.document.documentID, data: data))
                    }
                }
                DispatchQueue.main.async {
                    self.count += 1
                }
            }
    }
    
    func handleSend() {
        print(chatText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = ["fromId": fromId, "toId": toId, "text": chatText, "timestamp": Timestamp(), "likes": []] as [String: Any]
        
        document.setData(messageData) { error in
            if let error = error {
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            print("Successfully saved current user sending message")
            self.persistRecentMessage()
            self.chatText = ""
            self.count += 1
        }
        
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            print("Recipient saved message as well")
        }
    }
    
    private func persistRecentMessage() {
        guard let chatUser = chatUser else { return }
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            "timestamp": Timestamp(),
            "text": self.chatText,
            "fromId": uid,
            "toId": toId,
            "profileImageUrl": chatUser.profileImageUrl,
            "email": chatUser.email
        ] as [String: Any]
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message: \(error)"
                print("Failed to save recent message: \(error)")
                return
            }
        }
    }
    
    func likeMessage(message: ChatMessage) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let messageRef = FirebaseManager.shared.firestore
            .collection("messages")
            .document(message.fromId)
            .collection(message.toId)
            .document(message.documentId)
        
        messageRef.getDocument { document, error in
            if let error = error {
                self.errorMessage = "Failed to fetch message: \(error)"
                print(error)
                return
            }
            
            guard var data = document?.data(), var likes = data["likes"] as? [String] else { return }
            
            var updatedLikes = likes
            
            if updatedLikes.contains(currentUserId) {
                updatedLikes.removeAll { $0 == currentUserId }
            } else {
                updatedLikes.append(currentUserId)
            }
            messageRef.updateData(["likes": updatedLikes]) { error in
                if let error = error {
                    self.errorMessage = "Failed to update likes: \(error)"
                    print(error)
                    return
                }
                print("Successfully updated likes")
            }
        }
    }
}

struct ChatLogView: View {
    
    let chatUser: ChatUser?
    @ObservedObject var vm: ChatLogViewModel
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        self.vm = ChatLogViewModel(chatUser: chatUser)
    }
    
    var body: some View {
        ZStack {
            VStack {
                messagesView
                Spacer()
                chatBottomBar
                    .background(Color.white)
            }
        }
        .navigationTitle(chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var messagesView: some View {
        ScrollView {
            ScrollViewReader { scrollViewProxy in
                VStack {
                    ForEach(vm.chatMessages) { message in
                        MessageView(message: message)
                            .contextMenu {
                                Button(action: {
                                    vm.likeMessage(message: message)
                                }) {
                                    HStack {
                                        Text("Do you want to like this message?")
                                        Image(systemName: "hand.thumbsup")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }

                    }
                    HStack { Spacer() }
                        .id("bottom")
                }
                .onReceive(vm.$count) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        scrollViewProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.init(white: 0.95, alpha: 1)))
    }
    
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(Color(.darkGray))
            
            ZStack {
                if vm.chatText.isEmpty {
                    DescriptionPlaceHolder()
                }
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding()
    }
}
struct MessageView: View {
    
    let message: ChatMessage
    @State private var liked: Bool = false
    
    var body: some View {
        VStack {
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
                HStack {
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                        if liked {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                HStack {
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                        if liked {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .contextMenu {
            Button(action: {
                LikeManager.shared.likeMessage(message: message) { success in
                    if success {
                        liked.toggle()
                    }
                }
            }) {
                Label(liked ? "Unlike" : "Do you want to like this?", systemImage: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
        }
        .onAppear {
            LikeManager.shared.isLiked(message: message) { isLiked in
                self.liked = isLiked
            }
        }
    }
}

class LikeManager {
    
    static let shared = LikeManager()
    
    private init() {}
    
    func likeMessage(message: ChatMessage, completion: @escaping (Bool) -> Void) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else {
            completion(false)
            return
        }
        
        let messageRef = FirebaseManager.shared.firestore
            .collection("messages")
            .document(message.fromId)
            .collection(message.toId)
            .document(message.documentId)
        
        FirebaseManager.shared.firestore.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(messageRef)
            } catch let fetchError as NSError {
                print("Failed to fetch message: \(fetchError)")
                completion(false)
                return nil
            }
            
            guard var data = document.data(), var likes = data["likes"] as? [String] else {
                completion(false)
                return nil
            }
        
            if likes.contains(currentUserId) {
                likes.removeAll { $0 == currentUserId }
            } else {
                likes.append(currentUserId)
            }
            transaction.updateData(["likes": likes], forDocument: messageRef)
            return nil
            
        }) { (object, error) in
            if let error = error {
                print("Failed to update likes: \(error)")
                completion(false)
                return
            }
            print("Successfully updated likes")
            completion(true)
        }
    }
    
    func isLiked(message: ChatMessage, completion: @escaping (Bool) -> Void) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else {
            completion(false)
            return
        }
        
        let messageRef = FirebaseManager.shared.firestore
            .collection("messages")
            .document(message.fromId)
            .collection(message.toId)
            .document(message.documentId)
        
        messageRef.getDocument { document, error in
            if let error = error {
                print("Failed to fetch message: \(error)")
                completion(false)
                return
            }
            
            guard let data = document?.data(), let likes = data["likes"] as? [String] else {
                completion(false)
                return
            }
            
            completion(likes.contains(currentUserId))
        }
    }
}

#Preview {
    NavigationView {
        MainMessagesView()
    }
}
