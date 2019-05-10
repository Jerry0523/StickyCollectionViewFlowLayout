//
//  ViewController.swift
//  StickyCollectionViewFlowLayout
//
//  Created by Jerry Wong on 2019/3/20.
//  Copyright © 2019 com.jerry. All rights reserved.
//

import UIKit

struct CellModel {
    
    let sticky: Bool
    
    let color: UIColor
    
    init(sticky: Bool) {
        self.sticky = sticky
        self.color = UIColor(red: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1)
    }
    
}

let stickyIndeces = Set([5, 20, 35])

class ViewController: UIViewController, UICollectionViewDataSource, StickyCollectionViewFlowLayoutDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @objc dynamic var isVertical = false
    
    let data = (0..<50).map{ CellModel(
        sticky: stickyIndeces.contains($0)
    )}
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data.count
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print(indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let model = data[indexPath.row]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        if model.sticky {
            cell.layer.borderColor = UIColor.black.cgColor
            cell.layer.borderWidth = 5
        } else {
            cell.layer.borderWidth = 0
        }
        cell.backgroundColor = model.color
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if isVertical {
            return CGSize(width: collectionView.bounds.width, height: 40)
        } else {
            return CGSize(width: 80, height: collectionView.bounds.height)
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if isVertical {
            return CGSize(width: collectionView.bounds.width, height: 40)
        } else {
            return CGSize(width: 80, height: collectionView.bounds.height)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if isVertical {
            return CGSize(width: collectionView.bounds.width, height: 100)
        } else {
            return CGSize(width: 150, height: collectionView.bounds.height)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerFooterView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: kind == UICollectionView.elementKindSectionHeader ? "header" : "footer", for: indexPath)
        headerFooterView.backgroundColor = UIColor.orange
        return headerFooterView
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceAt indexPath: IndexPath) -> CGFloat? {
        let model = data[indexPath.row]
        if model.sticky {
            return 0
        }
        return nil
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceForHeaderInSection section: Int) -> CGFloat? {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceForFooterInSection section: Int) -> CGFloat? {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyInsetsDidChange stickyInsets: UIEdgeInsets) {
        collectionView.scrollIndicatorInsets = stickyInsets
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let dest = collectionView.collectionViewLayout.targetContentOffset(forProposedContentOffset: targetContentOffset.pointee)
        targetContentOffset.pointee = dest
    }
    
}
