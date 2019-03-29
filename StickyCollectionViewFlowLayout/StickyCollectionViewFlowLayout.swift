//
//  StickyCollectionViewFlowLayout.swift
//  StickyCollectionViewFlowLayout
//
//  Created by Jerry Wong on 2019/3/20.
//  Copyright © 2019 com.jerry. All rights reserved.
//

import UIKit

@objc protocol StickyCollectionViewFlowLayoutDelegate : UICollectionViewDelegateFlowLayout {
    
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceAt indexPath: IndexPath) -> NSNumber?
    
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceForHeaderInSection section: Int) -> NSNumber?
    
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceForFooterInSection section: Int) -> NSNumber?
    
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyInsetsDidChange stickyInsets: UIEdgeInsets)
    
}

open class StickyCollectionViewFlowLayout : UICollectionViewFlowLayout {
    
    open var fixedStickyContentOffset: CGPoint {
        get {
            guard let stickyElements = stickyElements,
                  stickyCursor >= 0,
                  stickyCursor < stickyElements.count else {
                return CGPoint.zero
            }
            let element = stickyElements[stickyCursor]
            return element.fixedOffset ?? CGPoint.zero
        }
    }
    
    override open var sectionHeadersPinToVisibleBounds: Bool {
        
        get { return false }
        
        set { }
    }
    
    override open var sectionFootersPinToVisibleBounds: Bool {
        
        get { return false }
        
        set { }
    }
    
    override open func prepare() {
        super.prepare()
        if shouldPrepareStickyElements {
            prepareStickyElements()
        }
    }
    
    override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return (stickyElements?.count ?? 0) > 0
    }
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attrs = super.layoutAttributesForElements(in: rect)
        
        if let stickyInfos = moveStickyElements(in: rect) {
            attrs = attrs?.filter { attr in stickyInfos.reduce(0, { $0 + ($1.element.matches(for: attr) ? 1 : 0) }) == 0 }
            attrs?.append(contentsOf: stickyInfos.map{ $0.attr })
        }
        return attrs
    }
    
    override open func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        shouldPrepareStickyElements = context.shouldPrepareStickyElements
        if shouldPrepareStickyElements {
            stickyElements = nil
            stickyCursor = 0
            stickyInsets = UIEdgeInsets.zero
        }
        super.invalidateLayout(with: context)
    }
    
    private func moveStickyElements(in rect: CGRect) -> [StickyInfo]? {
        guard
            let collectionView = collectionView,
            let stickyElements = stickyElements,
            stickyElements.count > stickyCursor else {
            return nil
        }
        let current = stickyElements[stickyCursor]
        let offset = scrollDirection == .vertical ? collectionView.contentOffset.y : collectionView.contentOffset.x
        let adjustedInset = scrollDirection == .vertical ? collectionView.adjustedContentInset.top : collectionView.adjustedContentInset.left
        for procedure in current.procedures {
            if let info = procedure(&self.stickyElements!, &stickyCursor, offset + adjustedInset, self) {
                return info
            }
        }
        return nil
    }
    
    private func prepareStickyElements() {
        guard let collectionView = collectionView, let delegate = collectionView.delegate else {
            return
        }
        guard let stickyDelegate = delegate as? StickyCollectionViewFlowLayoutDelegate else {
            fatalError()
        }
        let count = collectionView.numberOfSections
        stickyElements = ((0..<count).map { sectionIndex in
            let itemCount = collectionView.numberOfItems(inSection: sectionIndex)
            return (-1...itemCount).compactMap { itemIndex in
                let indexPath: IndexPath
                let category: StickyElement.Category
                let distance: NSNumber?
                switch itemIndex {
                case -1:
                    category = .header
                    indexPath = IndexPath(item: 0, section: sectionIndex)
                    distance = stickyDelegate.collectionView?(collectionView, layout: self, stickyDistanceForHeaderInSection: sectionIndex)
                case itemCount:
                    category = .footer
                    indexPath = IndexPath(item: 0, section: sectionIndex)
                    distance = stickyDelegate.collectionView?(collectionView, layout: self, stickyDistanceForFooterInSection: sectionIndex)
                default:
                    category = .cell
                    indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                    distance = stickyDelegate.collectionView?(collectionView, layout: self, stickyDistanceAt: indexPath)
                }
                
                if let distance = distance {
                    return StickyElement(category: category, indexPath: indexPath, distance: CGFloat(truncating: distance))
                } else {
                    return nil
                }
            }
        } as [[StickyElement]]).flatMap{ $0 }
    }
    
    private var stickyElements: [StickyElement]?
    
    private var stickyCursor = 0
    
    private var stickyInsets = UIEdgeInsets.zero {
        didSet {
            if oldValue != stickyInsets,
                let collectionView = collectionView,
                let delegate = collectionView.delegate as? StickyCollectionViewFlowLayoutDelegate {
                delegate.collectionView?(collectionView, layout: self, stickyInsetsDidChange: stickyInsets)
            }
        }
    }
    
    private var shouldPrepareStickyElements = false
    
    private struct StickyInfo {
        
        let element: StickyElement
        
        let attr: UICollectionViewLayoutAttributes
        
    }
    
    private struct StickyElement {
        
        typealias Procedure = (inout [StickyElement], inout Int, CGFloat, StickyCollectionViewFlowLayout) -> [StickyInfo]?
        
        public enum Category : UInt {
            
            case cell
            
            case header
            
            case footer
        }
        
        let category: Category
        
        let indexPath: IndexPath
        
        let distance: CGFloat
        
        var fixedOffset: CGPoint? = nil
        
        init(category: Category, indexPath: IndexPath, distance: CGFloat) {
            self.category = category
            self.indexPath = indexPath
            self.distance = distance
        }
        
        var procedures: [Procedure] {
            get {
                return [
                    replaceBackward,
                    replaceForward,
                    replacingForward,
                    replacingBackward,
                    keepSticky
                ]
            }
        }
        
        func matches(for layoutAttributes: UICollectionViewLayoutAttributes) -> Bool {
            switch layoutAttributes.representedElementCategory {
            case .cell:
                return category == .cell && layoutAttributes.indexPath == indexPath
            case .supplementaryView:
                switch layoutAttributes.representedElementKind {
                case UICollectionView.elementKindSectionHeader:
                    return category == .header && layoutAttributes.indexPath.section == indexPath.section
                case UICollectionView.elementKindSectionFooter:
                    return category == .footer && layoutAttributes.indexPath.section == indexPath.section
                default:
                    return false
                }
            default:
                return false
            }
        }
        
        func layoutAttribute(for layout: UICollectionViewLayout) -> UICollectionViewLayoutAttributes? {
            let ret: UICollectionViewLayoutAttributes?
            switch category {
            case .cell:
                ret = layout.layoutAttributesForItem(at: indexPath)
            case .header:
                ret = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: indexPath.section))
            case .footer:
                ret = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: indexPath.section))
            }
            return ret?.copy() as? UICollectionViewLayoutAttributes
        }
        
        private func with(fixedOffset: CGPoint?) -> StickyElement? {
            if self.fixedOffset == fixedOffset {
                return nil
            }
            var instance = self
            instance.fixedOffset = fixedOffset
            return instance
        }
        
        private static func replaceElement(fixedOffset: CGPoint?, cursor: Int, buffer: inout [StickyElement]) {
            let element = buffer[cursor]
            if let fixedElement = element.with(fixedOffset: fixedOffset) {
                buffer[cursor] = fixedElement
            }
        }
        
        private static func withValidAttr(_ e0: StickyElement, _ e1: StickyElement, for layout: UICollectionViewLayout) -> (UICollectionViewLayoutAttributes, UICollectionViewLayoutAttributes)? {
            
            guard let currentAttr = e0.layoutAttribute(for: layout),
                let refAttr = e1.layoutAttribute(for: layout),
                currentAttr.frame != CGRect.zero,
                refAttr.frame != CGRect.zero else {
                    return nil
            }
            return (currentAttr, refAttr)
        }
        
        func replaceBackward(with buffer: inout [StickyElement], cursor: inout Int, offset: CGFloat, for layout: StickyCollectionViewFlowLayout) -> [StickyInfo]? {
            
            guard cursor > 0 else {
                return nil
            }
            let reference = buffer[cursor - 1]
            guard let (currentAttr, refAttr) = StickyElement.withValidAttr(self, reference, for: layout) else {
                return nil
            }
            
            switch layout.scrollDirection {
            case .vertical:
                if currentAttr.frame.minY >= offset + reference.distance + refAttr.frame.height {
                    refAttr.transform = CGAffineTransform(translationX: 0, y: offset + reference.distance - refAttr.frame.minY)
                    refAttr.zIndex = StickyZIndex
                    StickyElement.replaceElement(fixedOffset: nil, cursor: cursor, buffer: &buffer)
                    cursor -= 1
                    layout.stickyInsets = UIEdgeInsets(top: refAttr.frame.height, left: 0, bottom: 0, right: 0)
                    return [StickyInfo(element: reference, attr: refAttr)]
                }
            case .horizontal:
                if currentAttr.frame.minX >= offset + reference.distance + refAttr.frame.width {
                    refAttr.transform = CGAffineTransform(translationX: offset + reference.distance - refAttr.frame.minX, y: 0)
                    refAttr.zIndex = StickyZIndex
                    StickyElement.replaceElement(fixedOffset: nil, cursor: cursor, buffer: &buffer)
                    cursor -= 1
                    layout.stickyInsets = UIEdgeInsets(top: 0, left: refAttr.frame.width, bottom: 0, right: 0)
                    return [StickyInfo(element: reference, attr: refAttr)]
                }
            @unknown default:
                break
            }
            return nil
        }
        
        func replaceForward(with buffer: inout [StickyElement], cursor: inout Int, offset: CGFloat, for layout: StickyCollectionViewFlowLayout) -> [StickyInfo]? {
            
            guard buffer.count > cursor + 1 else {
                return nil
            }
            let reference = buffer[cursor + 1]
            guard let (_, refAttr) = StickyElement.withValidAttr(self, reference, for: layout) else {
                return nil
            }
            
            switch layout.scrollDirection {
            case .vertical:
                if refAttr.frame.minY <= offset + reference.distance {
                    refAttr.transform = CGAffineTransform(translationX: 0, y: offset + reference.distance - refAttr.frame.minY)
                    refAttr.zIndex = StickyZIndex
                    StickyElement.replaceElement(fixedOffset: nil, cursor: cursor, buffer: &buffer)
                    cursor += 1
                    layout.stickyInsets = UIEdgeInsets(top: refAttr.frame.height, left: 0, bottom: 0, right: 0)
                    return [StickyInfo(element: reference, attr: refAttr)]
                }
            case .horizontal:
                if refAttr.frame.minX <= offset + reference.distance {
                    refAttr.transform = CGAffineTransform(translationX: offset + reference.distance - refAttr.frame.minX, y: 0)
                    refAttr.zIndex = StickyZIndex
                    StickyElement.replaceElement(fixedOffset: nil, cursor: cursor, buffer: &buffer)
                    cursor += 1
                    layout.stickyInsets = UIEdgeInsets(top: 0, left: refAttr.frame.width, bottom: 0, right: 0)
                    return [StickyInfo(element: reference, attr: refAttr)]
                }
            @unknown default:
                break
            }
            return nil
        }
        
        func replacingForward(with buffer: inout [StickyElement], cursor: inout Int, offset: CGFloat, for layout: StickyCollectionViewFlowLayout) -> [StickyInfo]? {
            
            guard buffer.count > cursor + 1 else {
                return nil
            }
            let reference = buffer[cursor + 1]
            guard let (currentAttr, refAttr) = StickyElement.withValidAttr(self, reference, for: layout) else {
                return nil
            }
            
            switch layout.scrollDirection {
            case .vertical:
                if refAttr.frame.minY < offset + distance + currentAttr.frame.height && refAttr.frame.minY > offset {
                    currentAttr.transform = CGAffineTransform(translationX: 0, y: refAttr.frame.minY - currentAttr.frame.minY - currentAttr.frame.height)
                    currentAttr.zIndex = StickyZIndex
                    
                    let progress = 1 - (refAttr.frame.minY - offset) / currentAttr.frame.height
                    if progress > 0.5 {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: 0, y: (1 - progress) * currentAttr.frame.height), cursor: cursor, buffer: &buffer)
                    } else {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: 0, y: -progress * currentAttr.frame.height), cursor: cursor, buffer: &buffer)
                    }
                    layout.stickyInsets = UIEdgeInsets(top: refAttr.frame.maxY - offset, left: 0, bottom: 0, right: 0)
                    return [StickyInfo(element: self, attr: currentAttr)]
                }
            case .horizontal:
                if refAttr.frame.minX < offset + distance + currentAttr.frame.width && refAttr.frame.minX > offset {
                    currentAttr.transform = CGAffineTransform(translationX: refAttr.frame.minX - currentAttr.frame.minX - currentAttr.frame.width, y: 0)
                    currentAttr.zIndex = StickyZIndex
                    
                    let progress = 1 - (refAttr.frame.minX - offset) / currentAttr.frame.width
                    if progress > 0.5 {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: (1 - progress) * currentAttr.frame.width, y: 0), cursor: cursor, buffer: &buffer)
                    } else {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: -progress * currentAttr.frame.width, y: 0), cursor: cursor, buffer: &buffer)
                    }
                    layout.stickyInsets = UIEdgeInsets(top: 0, left: refAttr.frame.maxX - offset, bottom: 0, right: 0)
                    return [StickyInfo(element: self, attr: currentAttr)]
                }
            @unknown default:
                break
            }
            
            return nil
        }
        
        func replacingBackward(with buffer: inout [StickyElement], cursor: inout Int, offset: CGFloat, for layout: StickyCollectionViewFlowLayout) -> [StickyInfo]? {
            
            guard cursor > 0 else {
                return nil
            }
            let reference = buffer[cursor - 1]
            guard let (currentAttr, refAttr) = StickyElement.withValidAttr(self, reference, for: layout) else {
                return nil
            }
            
            switch layout.scrollDirection {
            case .vertical:
                if currentAttr.frame.minY > offset + distance
                    && currentAttr.frame.minY < offset + reference.distance + refAttr.frame.height {
                    refAttr.transform = CGAffineTransform(translationX: 0, y: currentAttr.frame.minY - refAttr.frame.maxY)
                    refAttr.zIndex = StickyZIndex
                    
                    let progress = 1 - (currentAttr.frame.minY - offset) / refAttr.frame.height
                    if progress < 0.5 {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: 0, y: -progress * refAttr.frame.height), cursor: cursor, buffer: &buffer)
                    } else {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: 0, y: (1 - progress) * refAttr.frame.height), cursor: cursor, buffer: &buffer)
                    }
                    layout.stickyInsets = UIEdgeInsets(top: currentAttr.frame.maxY - offset, left: 0, bottom: 0, right: 0)
                    return [StickyInfo(element: reference, attr: refAttr)]
                }
            case .horizontal:
                if currentAttr.frame.minX > offset + distance
                    && currentAttr.frame.minX < offset + reference.distance + refAttr.frame.width {
                    refAttr.transform = CGAffineTransform(translationX: currentAttr.frame.minX - refAttr.frame.maxX, y: 0)
                    refAttr.zIndex = StickyZIndex
                    
                    let progress = 1 - (currentAttr.frame.minX - offset) / refAttr.frame.width
                    if progress < 0.5 {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: -progress * refAttr.frame.width, y: 0), cursor: cursor, buffer: &buffer)
                    } else {
                        StickyElement.replaceElement(fixedOffset: CGPoint(x: (1 - progress) * refAttr.frame.width, y: 0), cursor: cursor, buffer: &buffer)
                    }
                    layout.stickyInsets = UIEdgeInsets(top: 0, left: currentAttr.frame.maxX - offset, bottom: 0, right: 0)
                    return [StickyInfo(element: reference, attr: refAttr)]
                }
            @unknown default:
                break
            }
            
            return nil
        }
        
        func keepSticky(with buffer: inout [StickyElement], cursor: inout Int, offset: CGFloat, for layout: StickyCollectionViewFlowLayout) -> [StickyInfo]? {
            
            guard let currentAttr = layoutAttribute(for: layout),
                currentAttr.frame != CGRect.zero else {
                    return nil
            }
            
            switch layout.scrollDirection {
            case .vertical:
                if currentAttr.frame.minY < offset + distance || (offset + distance < 0 && indexPath == IndexPath(item: 0, section: 0)) {
                    currentAttr.transform = CGAffineTransform(translationX: 0, y: offset + distance - currentAttr.frame.minY)
                    currentAttr.zIndex = StickyZIndex
                    StickyElement.replaceElement(fixedOffset: nil, cursor: cursor, buffer: &buffer)
                    layout.stickyInsets = UIEdgeInsets(top: currentAttr.frame.height, left: 0, bottom: 0, right: 0)
                    return [StickyInfo(element: self, attr: currentAttr)]
                }
            case .horizontal:
                if currentAttr.frame.minX < offset + distance || (offset + distance < 0 && indexPath == IndexPath(item: 0, section: 0)) {
                    currentAttr.transform = CGAffineTransform(translationX: offset + distance - currentAttr.frame.minX, y: 0)
                    currentAttr.zIndex = StickyZIndex
                    StickyElement.replaceElement(fixedOffset: nil, cursor: cursor, buffer: &buffer)
                    layout.stickyInsets = UIEdgeInsets(top: 0, left: currentAttr.frame.width, bottom: 0, right: 0)
                    return [StickyInfo(element: self, attr: currentAttr)]
                }
            @unknown default:
                break
            }
            return nil
        }
        
    }
}

extension UICollectionViewLayoutInvalidationContext {
    
    var shouldPrepareStickyElements: Bool {
        get {
            let invalidCount = (invalidatedItemIndexPaths != nil ? invalidatedItemIndexPaths!.count : 0)
                + (invalidatedSupplementaryIndexPaths != nil ? invalidatedSupplementaryIndexPaths!.count : 0)
                + (invalidatedDecorationIndexPaths != nil ? invalidatedDecorationIndexPaths!.count : 0)
            return invalidateEverything || invalidateDataSourceCounts || invalidCount > 0
        }
    }
}

fileprivate let StickyZIndex = 10