//
//  RawdeaAuthCallbackRoute.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 25/11/2569 BE.
//

import Foundation

enum RawdeaAuthCallbackRoute: Equatable {

    case login
    case passwordRecovery

    init?(url: URL) {

        guard let scheme =
            url.scheme?.lowercased(),
              let host =
            url.host?.lowercased() else {

            return nil
        }

        switch (scheme, host) {

        case ("rawdea", "login-callback"),
             ("moist", "login-callback"):

            self = .login

        case ("rawdea", "password-recovery"):

            self = .passwordRecovery

        default:

            return nil
        }
    }
}

