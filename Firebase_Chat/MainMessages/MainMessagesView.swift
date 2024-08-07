//
//  MainMessagesView.swift
//  Firebase_Chat
//
//  Created by Marian Paliichuk on 06.08.2024.
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI
import Firebase

struct RecentMessage: Identifiable {
    
    var id: String { documentId }
    
    let documentId: String
    let text, email: String
    let fromId, toId: String
    let profileImageUrl: String
//    let  profileImageUrl: String
    let timestamp: Firebase.Timestamp
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.text = data["text"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.fromId = data["fromId"] as? String ?? ""
        self.toId = data["toId"] as? String ?? ""
        self.timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
    }
}

class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    
    
    init() {
        
        DispatchQueue.main.async {
            self.isUserCurrentlyLoggedOut =
            FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        
        fetchCurrentUser()
        
        fetchRecentMessages()
    }
    
    @Published var recentMessages = [RecentMessage]()
    
    public func fetchRecentMessages() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {return}
        
        FirebaseManager.shared.firestore.collection("recent_messages")
            .document(uid)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener {QuerySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for recent messages: \(error)"
                    print(error)
                    return
                }
                
                QuerySnapshot?.documentChanges.forEach({change in
                        let docId = change.document.documentID
                    
                    if let index = self.recentMessages.firstIndex(where: { rm in
                        return rm.documentId == docId
                    }) {
                        self.recentMessages.remove(at: index)
                    }
                    
                    self.recentMessages.insert(.init(documentId: docId, data: change.document.data()),at: 0)
                     
                    
                  //      self.recentMessages.append()
                })
            }
    }
    
    func fetchCurrentUser() {

        guard let uid =
                FirebaseManager.shared.auth
                .currentUser?.uid
        else {
            self.errorMessage = "Could not find firebase uid"
            return
        }


        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument {snapshot, error in
            if let error = error {
                self.errorMessage = "Failed to fetch current user: \(error)"
                print("Failed to fetch current user:",error)
                return
            }
            
            
            
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found"
                return
            }
//            self.errorMessage = "Data: \(data.description)"
            
            self.chatUser = .init(data: data)
            
   //         self.errorMessage = chatUser.profileImageUrl
        }
        
      
    }
    
    @Published var isUserCurrentlyLoggedOut = false
    
    func handleSignOut() {
        isUserCurrentlyLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
    }
    
}

struct MainMessagesView: View {
    
    @State var shouldShowLogOutOptions = false
    
    @State var shouldNavigateToChatLogView = false
    
    @ObservedObject private var vm = MainMessagesViewModel()
    
    var body: some View {
        NavigationView {
            
            
            VStack {
                //Text("User: \(vm.chatUser?.uid ?? "")")
                //custom nav bar
                customNavBar
                
                messagesView
                
                NavigationLink("",isActive: $shouldNavigateToChatLogView) {
                    ChatLogView(chatUser: self.chatUser)
                }
                newMessageButton
//                .overlay(newMessageButton,
//                    alignment: .bottom
//                )
//                .navigationBarHidden(true)
                
                
                
                //        .navigationTitle("Main Messages View")
            }
            .onAppear {
                if !vm.isUserCurrentlyLoggedOut {
                    vm.fetchRecentMessages()
                }
            }
        }
    }
    
    
    
    private var customNavBar: some View {
        //custom nav bar
        HStack(spacing: 16){
            
            WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipped()
                .cornerRadius(50)
                .overlay(RoundedRectangle(cornerRadius: 44)
                    .stroke(Color.black,lineWidth: 1)
                )
                .shadow(radius: 5)
            
//            Image(systemName: "person.fill")
//                .font(.system(size: 24, weight: .heavy))
            
            VStack(alignment: .leading, spacing: 4) {
                let email = vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? ""
                Text(email)
                    .font(.system(size: 24, weight: .bold))
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14,height: 14)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
                
            }
            
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                
                Image(systemName: "gear")
                    .font(.system(size: 24,weight: .bold))
                    .foregroundColor(Color(.label))
            }
        }
        .padding()
        .actionSheet(isPresented: $shouldShowLogOutOptions) {
            .init(title: Text("Settings"), message:
                    Text("What do you want to do?"),buttons:[
                        .destructive(Text("Sign Out"), action: {
                           print("Handle sign out")
                            vm.handleSignOut()
                        }),
//                                .default(Text("DEFAULT BUTTON"))
                        .cancel()
                    ])
        }
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut,
                         onDismiss: nil) {
            LoginView(didCompleteLoginProcess: {
                self.vm.isUserCurrentlyLoggedOut = false
                self.vm.fetchCurrentUser()
            })
        }
    
        
    }
    
    
    private var messagesView: some View {
        ScrollView {
            ForEach(vm.recentMessages) {recentMessage in
                VStack {
                    NavigationLink {
                        Text("Destination")
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable() // Ensure the image can be resized
                                .aspectRatio(contentMode: .fill) // Fill the frame while preserving aspect ratio
                                .frame(width: 64, height: 64) // Define the frame size
                                .clipped() // Clip the image to fit the frame
                                .cornerRadius(32) // Use a corner radius that matches half of the frame size
                                .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.black, lineWidth: 1)) // Adjust corner radius for overlay
                                .shadow(radius: 5) // Apply shadow if needed

                            
                            
                            VStack(alignment: .leading,spacing: 8) {
                                Text(recentMessage.email)
                                    .font(.system(size: 16,weight: .bold))
                                    .foregroundColor(Color(.label))
                                Text(recentMessage.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.darkGray))
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            Text(formattedDate(from: recentMessage.timestamp))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color(.lightGray))
                        }
                    }

                    Divider()
                        .padding(.vertical, 8)
                }.padding(.horizontal)
                
            }.padding(.bottom, 50)
        }
    }
    
    private func formattedDate(from timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm" // Custom format
        return dateFormatter.string(from: date)
    }
    
    @State var shouldShowNewMessageScreen = false
    
    private var newMessageButton: some View {
        Button(action: {
            shouldShowNewMessageScreen.toggle()
        }) {
            HStack {
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 25)
            .background(Color.blue)
            .cornerRadius(32)
            .shadow(radius: 15)
        }
        .frame(maxWidth: .infinity) // Make button full width to ensure visibility
        .padding() // Additional padding around the button

            .fullScreenCover(isPresented: $shouldShowNewMessageScreen) {
                CreateNewMessageView(didSelectNewUser: {user
                    in
                    print(user.email)
                    self.shouldNavigateToChatLogView.toggle()
                    self.chatUser = user
                })
            }
    }
    
    @State var chatUser: ChatUser?
        
}



#Preview {
    MainMessagesView()
}
