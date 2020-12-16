//
//  HistoryViewController.swift
//  PassioTakeHome
//
//  Created by Justin Brady on 12/16/20.
//  Copyright © 2020 Justin Brady. All rights reserved.
//

import Foundation
import UIKit

class HistoryViewController: UIViewController {
    
    var tableView: UITableView!
    var imageView: UIImageView!
    
    private var images: [UIImage] = []
    private var paths: [URL] = []
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let fileManager = FileManager.default
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // process files
            
            for url in fileURLs {
                
                guard let data = try? Data(contentsOf: url) else {
                    print("failed to load")
                    continue
                }
                
                if let img = UIImage(data: data) {
                    images.append(img)
                    paths.append(url)
                }
            }
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
        
        tableView = UITableView(frame: view.bounds)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        view.addSubview(tableView)
        
        imageView = UIImageView(frame: view.frame)
        imageView.isHidden = true
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.black
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onClose(_:)))
        imageView.addGestureRecognizer(tapGesture)
        imageView.isUserInteractionEnabled = true
        
        view.addSubview(imageView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView?.frame = view.bounds
    }
}

extension HistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // TODO: custom cell class
        let cell = UITableViewCell()
        
        cell.imageView?.image = images[indexPath.item]
        cell.imageView?.contentMode = .scaleAspectFit
        
        return cell
    }
}

extension HistoryViewController {
    @objc func onClose(_ sender: Any) {
        imageView?.isHidden = true
    }
}

extension HistoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        imageView.image = images[indexPath.item]
        imageView.isHidden = false
    }
}
