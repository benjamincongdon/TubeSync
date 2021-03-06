//
//  SyncHelper.swift
//  Playlist Sync
//
//  Created by Benjamin Congdon on 1/14/16.
//  Copyright © 2016 Benjamin Congdon. All rights reserved.
//

import Cocoa
import Foundation
import CocoaLumberjack

class SyncHelper: NSObject {
    
    //Directory pointing to the root of the sync folder
    var outputDir:String
    
    //Queues for download operations
    let downloadQueue = NSOperationQueue()
    let playlistQueue = NSOperationQueue()
    
    static let defaultHelper = SyncHelper()
    
    static private let fileManager = NSFileManager.defaultManager()
    
    let youtubeClient = YoutubeClient.defaultClient
    
    private override init(){
        self.outputDir = ""
        
        downloadQueue.maxConcurrentOperationCount = 3
        downloadQueue.qualityOfService = .Background
        
        playlistQueue.maxConcurrentOperationCount = 1
        playlistQueue.qualityOfService = .Background
        super.init()
    }
    
    //Returns a list of files (and potentially folders) at the given path
    static func listFolder(directory:String) -> Array<String>{
        let enumerator = fileManager.enumeratorAtPath(directory)
        var fileList = Array<String>()
        while let element = enumerator?.nextObject() as? String{
            fileList.append(element)
        }
        return fileList
    }
    
    //Tries to delete the file at the given string path
    private func deleteFile(path:String) -> Bool{
        do{
            try SyncHelper.fileManager.removeItemAtPath(path)
            return true
        }
        catch let error as NSError {
            print(error)
            return false
        }
    }
    
    //Tries to download the given playlist by refreshing and downloading files that haven't been downloaded yet
    func downloadPlaylist(playlist:Playlist) throws {
        
        let playlistFolderPath = NSString(string: outputDir).stringByAppendingPathComponent(playlist.title
        )
        
        //Updates the URLs in the playlist entry array to reflect the most up-to-date version
        try youtubeClient.refreshPlaylist(playlist)

        
        //Reset the playlist's internal download counter
        playlist.progress = 0
        
        let folderList = SyncHelper.listFolder(playlistFolderPath)
        
        for entry in playlist.entries {
            if entry.1 != "" && !folderList.contains(entry.1){
                print("Folder doesn't contain: " + entry.1)
                playlist.entries[entry.0] = ""
            }
        }
        for entry in playlist.entries {
            //Download video is filename is unknown, or if the video file isn't in outputDir
            if entry.1.isEmpty {
                let downloadOp = NSBlockOperation(block: {
                    print("Downloading: " + entry.0)
                    let fileName = YoutubeClient().downloadVideo(entry.0, path: playlistFolderPath)
                    //Inform playlist of the resulting file name
                    NSNotificationCenter.defaultCenter().postNotificationName(PlaylistFileDownloadedNotification, object: [entry.0, fileName])
                })
                downloadOp.completionBlock = {
                    NSNotificationCenter.defaultCenter().postNotificationName(PlaylistDownloadProgressNotification, object: playlist)
                }
                downloadQueue.addOperation(downloadOp)
                print("Operation count: \(downloadQueue.operationCount)")
            }
            else{
                NSNotificationCenter.defaultCenter().postNotificationName(PlaylistFileDownloadedNotification, object: [entry.0,entry.1])
                NSNotificationCenter.defaultCenter().postNotificationName(PlaylistDownloadProgressNotification, object: playlist)
                NSNotificationCenter.defaultCenter().postNotificationName(CurrentDownloadFileName, object: entry.1)
                print("found completed file")
            }
        }
        downloadQueue.waitUntilAllOperationsAreFinished()
        //Progress of -1 indicates completion
        playlist.progress = -1
    }
    
    func syncPlaylists(playlists:Array<Playlist>){
        if(downloadQueue.operationCount > 0){
            print("Not beginning sync because downloadQueue still has operations")
            NSNotificationCenter.defaultCenter().postNotificationName(SyncCompletionNotification, object: nil)
            return
        }
        else if(outputDir == "") {
            print("Warning: Not syncing because outputDir is blank.")
            NSNotificationCenter.defaultCenter().postNotificationName(SyncCompletionNotification, object: nil)
            return
        }
        for playlist in playlists{
            if playlist.enabled! {
                let downloadPlaylistOp = NSBlockOperation(block: {
                    do {
                        try self.downloadPlaylist(playlist)
                    }
                    catch YoutubeError.NetworkFailure{
                        self.haltSync()
                        print("Sync failed due to network failure.")
                        DDLogError("Sync failed due to network failure.")
                    }
                    catch {
                        self.haltSync()
                        NSNotificationCenter.defaultCenter().postNotificationName(PlaylistRefreshFailedNotification, object: playlist)
                    }
                })
                downloadPlaylistOp.completionBlock = {
                    print("* FINISHED DOWNLOADING " + playlist.title)
                    NSNotificationCenter.defaultCenter().postNotificationName(PlaylistSyncCompletionNotification, object: playlist)
                }
                playlistQueue.addOperation(downloadPlaylistOp)
            }
        }
        dispatch_async(GlobalBackgroundQueue){
            self.playlistQueue.waitUntilAllOperationsAreFinished()
            NSNotificationCenter.defaultCenter().postNotificationName(SyncCompletionNotification, object: nil)
        }
    }
    
    func haltSync(){
        downloadQueue.cancelAllOperations()
        playlistQueue.cancelAllOperations()
        NSNotificationCenter.defaultCenter().postNotificationName(SyncCompletionNotification, object: nil)
    }
}
