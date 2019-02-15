//
//  AddItemTableViewCell.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 30.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import SnapKit
import RxCocoa
import RxSwift

class AddItemTableViewCell: UITableViewCell {

    var addItemTextBox: UITextField!
    var firstItemSuggestion: UIButton!
    var seccondItemSuggestion: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.addItemTextBox = UITextField()
        self.addItemTextBox.borderStyle = UITextField.BorderStyle.roundedRect
        self.addItemTextBox.font = UIFont.systemFont(ofSize: 15)
        self.addItemTextBox.placeholder = "enter item"
        self.addItemTextBox.autocorrectionType = UITextAutocorrectionType.no
        self.addItemTextBox.keyboardType = UIKeyboardType.default
        self.addItemTextBox.returnKeyType = UIReturnKeyType.done
        self.addItemTextBox.clearButtonMode = UITextField.ViewMode.whileEditing
        self.addItemTextBox.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        
        self.firstItemSuggestion = UIButton()
        self.firstItemSuggestion.setTitle("First Hint", for: UIControl.State.normal)
        self.seccondItemSuggestion = UIButton()
        
        self.contentView.addSubview(addItemTextBox)
        self.contentView.addSubview(firstItemSuggestion)
        self.contentView.addSubview(seccondItemSuggestion)
        

        self.addItemTextBox.snp.makeConstraints { (make) in
            //make.top.equalTo(contentView).offset(5)
            make.left.equalTo(contentView).inset(5)
            make.right.equalTo(contentView).inset(-5)
            make.height.equalTo(30)
        }
       
        self.firstItemSuggestion.snp.makeConstraints { (make) in
            make.top.equalTo(addItemTextBox.snp.bottom).offset(16)
            make.left.equalTo(contentView).offset(5)
            make.bottom.equalTo(contentView).offset(-16)
            make.height.equalTo(30)
            make.width.equalTo(80)
        }
        
        self.seccondItemSuggestion.snp.makeConstraints { (make) in
            make.top.equalTo(addItemTextBox.snp.bottom).offset(16)
            make.right.equalTo(contentView).offset(-5)
            make.bottom.equalTo(contentView).offset(-16)
            make.height.equalTo(30)
            make.width.equalTo(80)
        }

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
