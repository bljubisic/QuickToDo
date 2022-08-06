//
//  ItemTableViewCell.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 30.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import SnapKit

class ItemTableViewCell: UITableViewCell {
    
    var used: UIButton!
    var itemName: UILabel!
    var cloud: UIImageView!
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.used = UIButton()
        self.itemName = UILabel()
        self.cloud = UIImageView()
        self.contentView.addSubview(used)
        self.contentView.addSubview(itemName)
        self.contentView.addSubview(cloud)
        self.used.snp.makeConstraints { make in
            make.centerY.equalTo(self.contentView.snp.centerY)
            make.left.equalTo(self.contentView).inset(5)
            make.width.equalTo(35)
            make.height.equalTo(35)
        }
        
        self.itemName.snp.makeConstraints { make in
            make.centerY.equalTo(self.contentView.snp.centerY)
            make.left.equalTo(self.used.snp.right).inset(-8)
            make.right.equalTo(self.contentView).inset(-5)
            make.height.equalTo(20)
        }
        self.cloud.snp.makeConstraints { make in
            make.centerY.equalTo(self.contentView.snp.centerY)
            make.right.equalTo(self.contentView).inset(10)
            make.height.equalTo(27)
            make.width.equalTo(36)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

}
