// 
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import UIKit

/// Provides utilities funcs to handle Pills inside attributed strings.
@available (iOS 15.0, *)
@objcMembers
class StringPillsUtils: NSObject {
    // MARK: - Internal Methods
    /// Insert text attachments for pills inside given message attributed string.
    ///
    /// - Parameters:
    ///   - attributedString: message string to update
    ///   - session: current session
    ///   - event: the event
    ///   - roomState: room state for message
    ///   - isEditMode: whether this string will be used in the composer
    /// - Returns: new attributed string with pills
    static func insertPills(in attributedString: NSAttributedString,
                            withSession session: MXSession,
                            event: MXEvent,
                            andRoomState roomState: MXRoomState,
                            isEditMode: Bool = false) -> NSAttributedString {
        let newAttr = NSMutableAttributedString(attributedString: attributedString)
        let totalRange = NSRange(location: 0, length: newAttr.length)

        newAttr.vc_enumerateAttribute(.link, in: totalRange) { (url: URL, range: NSRange, _) in
            if let userId = userIdFromPermalink(url.absoluteString),
               let roomMember = roomState.members.member(withUserId: userId) {
                let isCurrentUser = roomMember.userId == session.myUserId && event.sender != session.myUserId
                let attachmentString = mentionPill(withRoomMember: roomMember,
                                                   andUrl: isEditMode ? nil : url,
                                                   isCurrentUser: isCurrentUser)
                newAttr.replaceCharacters(in: range, with: attachmentString)
            }
        }

        return newAttr
    }

    /// Creates a string with all pills of given attributed string replaced by display names.
    ///
    /// - Parameters:
    ///   - attributedString: attributed string with pills
    ///   - asMarkdown: wether pill should be replaced by markdown links or raw text
    /// - Returns: string with display names
    static func stringByReplacingPills(in attributedString: NSAttributedString, asMarkdown: Bool = false) -> String {
        let newAttr = NSMutableAttributedString(attributedString: attributedString)
        let totalRange = NSRange(location: 0, length: newAttr.length)

        newAttr.vc_enumerateAttribute(.attachment, in: totalRange) { (attachment: PillTextAttachment, range: NSRange, _) in
            if let displayname = attachment.roomMember?.displayname,
               let userId = attachment.roomMember?.userId,
               let permalink = MXTools.permalinkToUser(withUserId: userId) {
                let pillString = asMarkdown ? "[\(displayname)](\(permalink))" : "\(displayname)"
                newAttr.replaceCharacters(in: range, with: pillString)
            }
        }

        return newAttr.string
    }

    /// Creates an attributed string containing a pill for given room member.
    ///
    /// - Parameters:
    ///   - roomMember: the room member
    ///   - url: URL to room member profile. Should be provided to make pill act as a link.
    ///   - isCurrentUser: true to indicate that the room member is the current user
    /// - Returns: attributed string with a pill attachment and an optional link
    static func mentionPill(withRoomMember roomMember: MXRoomMember,
                            andUrl url: URL? = nil,
                            isCurrentUser: Bool) -> NSAttributedString {
        let attachment = PillTextAttachment(withRoomMember: roomMember, isCurrentUser: isCurrentUser)
        let string = NSMutableAttributedString(attachment: attachment)
        string.addAttribute(.font, value: UIFont.systemFont(ofSize: 15.0), range: .init(location: 0, length: string.length))
        if let url = url {
            string.addAttribute(.link, value: url, range: .init(location: 0, length: string.length))
        }
        return string
    }

    /// Extract user id from given permalink
    /// - Parameter permalink: the permalink
    /// - Returns: userId, if any
    private static func userIdFromPermalink(_ permalink: String) -> String? {
        let baseUrl: String
        if let clientBaseUrl = BuildSettings.clientPermalinkBaseUrl {
            baseUrl = String(format: "%@/#/user/", clientBaseUrl)
        } else {
            baseUrl = String(format: "%@/#/", kMXMatrixDotToUrl)
        }
        return permalink.starts(with: baseUrl) ? String(permalink.dropFirst(baseUrl.count)) : nil
    }
}
