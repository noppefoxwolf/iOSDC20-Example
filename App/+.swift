//
//  +.swift
//  App
//
//  Created by Tomoya Hirano on 2020/08/16.
//

import UIKit

extension UIView {
    func fillLayout() {
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            superview!.topAnchor.constraint(equalTo: self.topAnchor),
            superview!.rightAnchor.constraint(equalTo: self.rightAnchor),
            superview!.leftAnchor.constraint(equalTo: self.leftAnchor),
            superview!.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }
}
