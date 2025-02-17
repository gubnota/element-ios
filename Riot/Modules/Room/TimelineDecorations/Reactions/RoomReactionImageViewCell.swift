/*
 Copyright 2019 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit
import Reusable

final class RoomReactionImageViewCell: UICollectionViewCell, NibReusable, Themable {
    
    // MARK: - Constants

    // MARK: - Properties
    
    // MARK: Outlets

    @IBOutlet private weak var reactionBackgroundView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    
    // MARK: Private
    
    private var theme: Theme?
    
    // MARK: Public
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        self.reactionBackgroundView.layer.masksToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        self.reactionBackgroundView.layer.cornerRadius = self.reactionBackgroundView.bounds.midY
    }

    // MARK: - Life cycle
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        /*
         On iOS 12, there are issues with self-sizing cells as described in Apple release notes (https://developer.apple.com/documentation/ios_release_notes/ios_12_release_notes) :
         "You might encounter issues with systemLayoutSizeFitting(_:) when using a UICollectionViewCell subclass that requires updateConstraints().
         (42138227) — Workaround: Don't call the cell's setNeedsUpdateConstraints() method unless you need to support live constraint changes.
         If you need to support live constraint changes, call updateConstraintsIfNeeded() before calling systemLayoutSizeFitting(_:)."
         */
        self.updateConstraintsIfNeeded()
        
        return super.preferredLayoutAttributesFitting(layoutAttributes)
    }
    
    // MARK: - Public
    
    func fill(actionIcon: UIImage) {
        imageView.image = actionIcon.withRenderingMode(.alwaysTemplate)
        self.updateViews()
    }
    
    func update(theme: Theme) {
        self.theme = theme
        self.updateViews()
    }
    
    // MARK: - Private
    
    private func updateViews() {
        self.imageView.tintColor = self.theme?.textSecondaryColor
        
        self.reactionBackgroundView.layer.borderWidth = 0.0
        self.reactionBackgroundView.backgroundColor = self.theme?.headerBackgroundColor
    }
}
