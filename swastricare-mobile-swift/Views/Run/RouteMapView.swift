//
//  RouteMapView.swift
//  swastricare-mobile-swift
//
//  Native MapKit implementation for proper route rendering
//  Routes scale correctly with map zoom/pan
//

import SwiftUI
import MapKit

// MARK: - Route Map View (UIKit-based for proper polyline rendering)

struct RouteMapView: UIViewRepresentable {
    let routeCoordinates: [CLLocationCoordinate2D]
    let showsUserLocation: Bool
    let isLiveTracking: Bool
    var userTrackingMode: MKUserTrackingMode = .follow
    
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = false
        
        // Set map style
        mapView.mapType = .standard
        
        // Configure for live tracking
        if isLiveTracking {
            mapView.userTrackingMode = userTrackingMode
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add route polyline if we have coordinates
        if routeCoordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline)
            
            // Add start marker
            let startAnnotation = RouteAnnotation(
                coordinate: routeCoordinates.first!,
                type: .start
            )
            mapView.addAnnotation(startAnnotation)
            
            // Add end marker (only if not live tracking, or if we have a route)
            if !isLiveTracking || routeCoordinates.count > 5 {
                let endAnnotation = RouteAnnotation(
                    coordinate: routeCoordinates.last!,
                    type: .end
                )
                mapView.addAnnotation(endAnnotation)
            }
        }
        
        // Update region if not live tracking (live tracking follows user)
        if !isLiveTracking && routeCoordinates.count >= 2 {
            let rect = polylineBoundingRect(coordinates: routeCoordinates)
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: false)
        } else if !isLiveTracking {
            mapView.setRegion(region, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func polylineBoundingRect(coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.union(pointRect)
        }
        // Add padding
        let padding = rect.size.width * 0.2
        return rect.insetBy(dx: -padding, dy: -padding)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapView
        
        init(_ parent: RouteMapView) {
            self.parent = parent
        }
        
        // Render polyline
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1.0) // Green color
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // Render annotations
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize user location
            if annotation is MKUserLocation {
                return nil
            }
            
            guard let routeAnnotation = annotation as? RouteAnnotation else {
                return nil
            }
            
            let identifier = routeAnnotation.type.rawValue
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Create custom marker image
            let size: CGFloat = 20
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            let image = renderer.image { context in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                
                // Draw circle
                let color: UIColor = routeAnnotation.type == .start ? .systemGreen : .systemRed
                color.setFill()
                
                context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
                
                // Draw border
                UIColor.white.setStroke()
                context.cgContext.setLineWidth(2)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
            }
            
            annotationView?.image = image
            annotationView?.centerOffset = CGPoint(x: 0, y: 0)
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

// MARK: - Route Annotation

class RouteAnnotation: NSObject, MKAnnotation {
    enum AnnotationType: String {
        case start = "start"
        case end = "end"
    }
    
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    
    init(coordinate: CLLocationCoordinate2D, type: AnnotationType) {
        self.coordinate = coordinate
        self.type = type
        super.init()
    }
}

// MARK: - Live Tracking Map View (follows user)

struct LiveTrackingMapView: UIViewRepresentable {
    let routeCoordinates: [CLLocationCoordinate2D]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays (but keep annotations for start marker)
        mapView.removeOverlays(mapView.overlays)
        
        // Only update annotations if route changed significantly
        let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        
        // Add route polyline if we have coordinates
        if routeCoordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline)
            
            // Add start marker only once
            if existingAnnotations.isEmpty, let firstCoord = routeCoordinates.first {
                let startAnnotation = RouteAnnotation(
                    coordinate: firstCoord,
                    type: .start
                )
                mapView.addAnnotation(startAnnotation)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1.0)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            guard let routeAnnotation = annotation as? RouteAnnotation else {
                return nil
            }
            
            let identifier = "startMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                
                // Create green start marker
                let size: CGFloat = 20
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                let image = renderer.image { context in
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    UIColor.systemGreen.setFill()
                    context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
                    UIColor.white.setStroke()
                    context.cgContext.setLineWidth(2)
                    context.cgContext.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
                }
                annotationView?.image = image
            }
            
            return annotationView
        }
    }
}

// MARK: - Static Summary Map View

struct SummaryRouteMapView: UIViewRepresentable {
    let routePoints: [LocationPoint]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Clear existing
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard routePoints.count >= 2 else { return }
        
        // Convert to coordinates
        let coordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        // Add polyline
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Add start/end markers
        let startAnnotation = RouteAnnotation(coordinate: coordinates.first!, type: .start)
        let endAnnotation = RouteAnnotation(coordinate: coordinates.last!, type: .end)
        mapView.addAnnotation(startAnnotation)
        mapView.addAnnotation(endAnnotation)
        
        // Fit map to route
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.union(pointRect)
        }
        let padding = rect.size.width * 0.15
        let paddedRect = rect.insetBy(dx: -padding, dy: -padding)
        mapView.setVisibleMapRect(paddedRect, edgePadding: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30), animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1.0)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RouteAnnotation else {
                return nil
            }
            
            let identifier = routeAnnotation.type.rawValue
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                
                let size: CGFloat = 16
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                let image = renderer.image { context in
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    let color: UIColor = routeAnnotation.type == .start ? .systemGreen : .systemRed
                    color.setFill()
                    context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
                    UIColor.white.setStroke()
                    context.cgContext.setLineWidth(2)
                    context.cgContext.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
                }
                annotationView?.image = image
            }
            
            return annotationView
        }
    }
}

// MARK: - Activity Route Map View (for ActivityDetailView using CoordinatePoint)

struct ActivityRouteMapView: UIViewRepresentable {
    let routeCoordinates: [CoordinatePoint]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Clear existing
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard routeCoordinates.count >= 2 else { return }
        
        // Convert to CLLocationCoordinate2D
        let coordinates = routeCoordinates.map { $0.coordinate }
        
        // Add polyline
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Add start/end markers
        let startAnnotation = RouteAnnotation(coordinate: coordinates.first!, type: .start)
        let endAnnotation = RouteAnnotation(coordinate: coordinates.last!, type: .end)
        mapView.addAnnotation(startAnnotation)
        mapView.addAnnotation(endAnnotation)
        
        // Fit map to route
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.union(pointRect)
        }
        let padding = Swift.max(rect.size.width, rect.size.height) * 0.15
        let paddedRect = rect.insetBy(dx: -padding, dy: -padding)
        mapView.setVisibleMapRect(paddedRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // Use blue color for activity detail (matching original design)
                renderer.strokeColor = UIColor(red: 0.31, green: 0.275, blue: 0.898, alpha: 1.0) // #4F46E5
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RouteAnnotation else {
                return nil
            }
            
            let identifier = routeAnnotation.type.rawValue
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                
                let size: CGFloat = 16
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                let image = renderer.image { context in
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    let color: UIColor = routeAnnotation.type == .start ? .systemGreen : .systemRed
                    color.setFill()
                    context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
                    UIColor.white.setStroke()
                    context.cgContext.setLineWidth(2)
                    context.cgContext.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
                }
                annotationView?.image = image
            }
            
            return annotationView
        }
    }
}

// MARK: - Activity Route Thumbnail Map View (for list card – same projection as detail)

/// Small map thumbnail that draws the route with MKPolyline so the track layout matches the detail screen.
struct ActivityRouteThumbnailMapView: UIViewRepresentable {
    let routeCoordinates: [CoordinatePoint]
    var size: CGSize = CGSize(width: 80, height: 80)
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard
        mapView.clipsToBounds = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard routeCoordinates.count >= 2 else { return }
        
        let coordinates = routeCoordinates.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Calculate bounding region for the route
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coordinate in coordinates {
            minLat = Swift.min(minLat, coordinate.latitude)
            maxLat = Swift.max(maxLat, coordinate.latitude)
            minLon = Swift.min(minLon, coordinate.longitude)
            maxLon = Swift.max(maxLon, coordinate.longitude)
        }
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // Calculate span with extra padding for small thumbnails
        let latDelta = (maxLat - minLat) * 1.5  // 50% padding
        let lonDelta = (maxLon - minLon) * 1.5  // 50% padding
        
        // Ensure minimum span for very short routes
        let minSpan = 0.002  // ~200 meters minimum span
        let span = MKCoordinateSpan(
            latitudeDelta: Swift.max(latDelta, minSpan),
            longitudeDelta: Swift.max(lonDelta, minSpan)
        )
        
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.31, green: 0.275, blue: 0.898, alpha: 1.0)
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleCoordinates = [
        CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
        CLLocationCoordinate2D(latitude: 12.9726, longitude: 77.5956),
        CLLocationCoordinate2D(latitude: 12.9736, longitude: 77.5966),
        CLLocationCoordinate2D(latitude: 12.9746, longitude: 77.5976),
        CLLocationCoordinate2D(latitude: 12.9756, longitude: 77.5986)
    ]
    
    return LiveTrackingMapView(routeCoordinates: sampleCoordinates)
        .frame(height: 300)
}
