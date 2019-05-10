# StickyCollectionViewFlowLayout

A UICollectionViewFlowLayout subclass that supports CSS sticky style.

You could pin everything(item/header/footer) to the edge of the collectionView with a specific distance.

![alt tag](https://raw.githubusercontent.com/Jerry0523/StickyCollectionViewFlowLayout/master/screenshot.gif)

How to use
-------
Just use it like the UICollectionViewFlowLayout
```swift
let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: StickyCollectionViewFlowLayout())
collectionView.delegate = self
```

Extra Delegates
-------
- Ask you about the specific distance you want to pin the cell with. Return nil if not a sticky element. 
```swift
func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceAt indexPath: IndexPath) -> CGFloat?
```
- Asks you about the specific distance you want to pin the header with. Return nil if not a sticky element. 
```swift
func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceForHeaderInSection section: Int) -> CGFloat?
```

- Ask you about the specific distance you want to pin the footer with. Return nil if not a sticky element. 
```swift
func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyDistanceForFooterInSection section: Int) -> CGFloat?
```

- Notify you that the current edge insets made by the sticky elements, which could be used to update the scroll indicator insets.
```swift
func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, stickyInsetsDidChange stickyInsets: UIEdgeInsets)
```
