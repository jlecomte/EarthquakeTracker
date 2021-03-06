//
//  MapViewController.swift
//  EarthquakeTracker
//
//  Created by Julien Lecomte on 10/11/14.
//  Copyright (c) 2014 Julien Lecomte. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class EarthquakePointAnnotation: MKPointAnnotation {

    var earthquake: Earthquake!
}

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var map: MKMapView!

    var locmgr: CLLocationManager!
    var annotations: [MKPointAnnotation] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup location manager...
        locmgr = CLLocationManager()
        locmgr.delegate = self
        locmgr.desiredAccuracy = kCLLocationAccuracyBest
        if (locmgr.respondsToSelector(Selector("requestWhenInUseAuthorization"))) {
            locmgr.requestWhenInUseAuthorization()
        }
        locmgr.startUpdatingLocation()

        // Setup map view...
        map.delegate = self
        map.showsUserLocation = true
    }

    override func viewDidAppear(animated: Bool) {
        // In case you just changed your settings...
        refreshMapAnnotations()
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        // We only need the user's location once, so stop updating location immediately!
        locmgr.stopUpdatingLocation()

        var location = locations[0] as CLLocation
        var region = MKCoordinateRegionMakeWithDistance(location.coordinate, 100000, 100000)
        map.setRegion(region, animated: true)
    }

    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        refreshMapAnnotations()
    }

    func refreshMapAnnotations() {
        // This trivial implementation removes all existing annotations,
        // requests the USGS service, and creates new annotations based
        // on the data returned whenever the user moves the map or zooms
        // in or out. Needless to say that it is highly inefficient...

        let client = USGSClient.sharedInstance
        client.setRegion(map.region.center, maxradius: max(map.region.span.latitudeDelta, map.region.span.longitudeDelta))

        client.getEarthquakeList() {
            (earthquakes: [Earthquake]!, error: NSError!) -> Void in

            if error != nil {
                var alert = UIAlertController(title: "Error", message: error.description, preferredStyle: UIAlertControllerStyle.Alert)
                self.presentViewController(alert, animated: false, completion: nil)
            } else {
                // This copies the array...
                var oldAnnotations = self.map.annotations

                // First add new annotations...
                for earthquake in earthquakes {
                    var epa = EarthquakePointAnnotation()

                    epa.earthquake = earthquake

                    epa.coordinate = CLLocationCoordinate2D(
                        latitude: earthquake.latitude as CLLocationDegrees!,
                        longitude: earthquake.longitude  as CLLocationDegrees!)

                    let dateFormatter = NSDateFormatter()
                    dateFormatter.dateFormat = "M/d 'at' h:m a"
                    let time = dateFormatter.stringFromDate(earthquake.time!)

                    epa.title = "Mag. \(earthquake.magnitude!) event on \(time)"
                    epa.subtitle = earthquake.place

                    self.map.addAnnotation(epa)
                }

                // ... and only remove the old ones to prevent flickering!
                self.map.removeAnnotations(oldAnnotations)
            }
        }
    }

    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if !annotation.isKindOfClass(EarthquakePointAnnotation) {
            return nil
        }

        var epa = annotation as EarthquakePointAnnotation

        var v = map.dequeueReusableAnnotationViewWithIdentifier("EarthquakePin") as MKPinAnnotationView!
        if v == nil {
            v = MKPinAnnotationView(annotation: epa, reuseIdentifier: "EarthquakePin")
        }

        v.canShowCallout = true

        if epa.earthquake.magnitude < 2.5 {
            v.image = UIImage(named: "map_pin_green")
        } else if epa.earthquake.magnitude < 3.5 {
            v.image = UIImage(named: "map_pin_yellow")
        } else if epa.earthquake.magnitude < 5 {
            v.image = UIImage(named: "map_pin_orange")
        } else {
            v.image = UIImage(named: "map_pin_red")
        }

        return v
    }
}
