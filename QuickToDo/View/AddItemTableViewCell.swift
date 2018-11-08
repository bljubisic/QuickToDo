//
//  AddItemTableViewCell.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 30.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import SnapKit

class AddItemTableViewCell: UITableViewCell {

    var addItemTextBox: UITextField!
    var firstItemSuggestion: UIButton!
    var seccondItemSuggestion: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.addItemTextBox = UITextField()
        self.addItemTextBox.snp.makeConstraints { (make) in
            make.top.equalTo(contentView).inset(5)
            make.left.equalTo(contentView).inset(5)
            make.right.equalTo(contentView).inset(-5)
            make.height.equalTo(30)
        }
        self.firstItemSuggestion = UIButton()
        self.firstItemSuggestion.snp.makeConstraints { (make) in
            make.top.equalTo(self.addItemTextBox.snp.bottom).inset(16)
            make.left.equalTo(contentView).inset(5)
            make.bottom.equalTo(contentView).inset(-16)
            make.height.equalTo(30)
            make.width.equalTo(80)
        }
        self.seccondItemSuggestion = UIButton()
        self.seccondItemSuggestion.snp.makeConstraints { (make) in
            make.top.equalTo(self.addItemTextBox.snp.bottom).inset(16)
            make.right.equalTo(contentView).inset(-5)
            make.bottom.equalTo(contentView).inset(-16)
            make.height.equalTo(30)
            make.width.equalTo(80)
        }
        self.contentView.addSubview(addItemTextBox)
        self.contentView.addSubview(firstItemSuggestion)
        self.contentView.addSubview(seccondItemSuggestion)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
