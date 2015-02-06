//
//  InputTableViewCell.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 11/8/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit

class InputTableViewCell: UITableViewCell {

    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var addButton2: UIButton!
    @IBOutlet weak var addButton1: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
