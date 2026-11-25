//
//  SignUpView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//
import SwiftUI

struct SignUpView: View {

    @ObservedObject var authViewModel:
        AuthViewModel

    var body: some View {

        RawdeaAuthFormView(
            authViewModel: authViewModel,
            mode: .signUp
        )
    }
}
