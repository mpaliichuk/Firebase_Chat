import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct LoginView: View {

    let didCompleteLoginProcess: () -> ()

    @State private var isLoginMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var shouldShowImagePicker = false
    @State private var image: UIImage?
    @State private var loginStatusMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Picker(selection: $isLoginMode, label: Text("Picker here")) {
                        Text("Login").tag(true)
                        Text("Create Account").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if !isLoginMode {
                        Button {
                            shouldShowImagePicker.toggle()
                        } label: {
                            VStack {
                                if let image = self.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .frame(width: 128, height: 128)
                                        .scaledToFill()
                                        .cornerRadius(64)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 64))
                                        .padding()
                                        .foregroundColor(Color(.label))
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.black, lineWidth: 3))
                        }
                    }

                    Group {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Password", text: $password)
                    }
                    .padding(12)
                    .background(Color.white)

                    Button {
                        handleAction()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isLoginMode ? "Log In" : "Create Account")
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .background(Color.blue)
                    }

                    Text(loginStatusMessage)
                        .foregroundColor(.red)
                }
                .padding()
            }
            .navigationTitle(isLoginMode ? "Log in" : "Create Account")
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
        }
    }

    private func handleAction() {
        if isLoginMode {
            loginUser()
        } else {
            createNewAccount()
        }
    }

    private func loginUser() {
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, err in
            if let err = err {
                print("Failed to login user:", err)
                loginStatusMessage = "Failed to login user: \(err.localizedDescription)"
                return
            }

            print("Successfully logged in as user: \(result?.user.uid ?? "")")
            loginStatusMessage = "Successfully logged in as user: \(result?.user.uid ?? "")"
            didCompleteLoginProcess()
        }
    }

    private func createNewAccount() {
        guard image != nil else {
            loginStatusMessage = "You must select an avatar image"
            return
        }

        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, error in
            if let err = error {
                print("Failed to create user:", err)
                loginStatusMessage = "Failed to create user: \(err.localizedDescription)"
                return
            }

            print("Successfully created user: \(result?.user.uid ?? "")")
            loginStatusMessage = "Successfully created user: \(result?.user.uid ?? "")"
            persistImageToStorage()
        }
    }

    private func persistImageToStorage() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = image?.jpegData(compressionQuality: 0.5) else { return }

        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                loginStatusMessage = "Failed to push image to Storage: \(err.localizedDescription)"
                return
            }

            ref.downloadURL { url, err in
                if let err = err {
                    loginStatusMessage = "Failed to retrieve downloadURL: \(err.localizedDescription)"
                    return
                }

                guard let url = url else { return }
                storeUserInformation(imageProfileUrl: url)
            }
        }
    }

    private func storeUserInformation(imageProfileUrl: URL) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            loginStatusMessage = "You must be logged in to store user information."
            return
        }

        let userData = [
            "email": email,
            "uid": uid,
            "profileImageUrl": imageProfileUrl.absoluteString
        ]

        FirebaseManager.shared.firestore.collection("users").document(uid).setData(userData) { error in
            if let error = error {
                print("Error saving user data: \(error.localizedDescription)")
                loginStatusMessage = "Failed to store user information: \(error.localizedDescription)"
                return
            }

            print("User information successfully stored.")
            loginStatusMessage = "User information successfully saved."
            didCompleteLoginProcess()
        }
    }
}
#Preview {
    LoginView(didCompleteLoginProcess: {
        
    })
}
