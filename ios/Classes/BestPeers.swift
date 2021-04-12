import Foundation
import SwiftSocket
import CocoaAsyncSocket

public class BestPeersResult {
    var isSuccessful: Bool
    var message: String?
    var peers: [PeerInfo]
    
    private init(isSuccessful: Bool, message: String?, peers: [PeerInfo]) {
        self.isSuccessful = isSuccessful
        self.message = message
        self.peers = peers
    }
    
    static func Error(message: String) -> BestPeersResult {
        return BestPeersResult(isSuccessful: false, message: message, peers: [PeerInfo]())
    }
    
    static func Success(peers: [PeerInfo]) -> BestPeersResult {
        return BestPeersResult(isSuccessful: true, message: nil, peers: peers)
    }
}

public class BestPeers : NSObject, GCDAsyncSocketDelegate {
    var peers = [PeerInfo]()
    
    public func GetBestPeers(completionHandler: (BestPeersResult) -> Void) -> Void {
        guard let url = URL(string: "https://jimber.io/peers.html") else {
            completionHandler(BestPeersResult.Error(message: "Invalid url"))
            return
        }
        
        do {
            let htmlData = try String(contentsOf: url, encoding: .ascii)
        
            let pattern = "((tcp|tls):\\/\\/(.*?))<\\/"
            let regex = try! NSRegularExpression(pattern: pattern)
            
            var fastPeers = 0
            
            regex.enumerateMatches(in: htmlData, options: [], range: NSRange(location: 0, length: htmlData.utf16.count)) { (result, _, stop) in
                guard let group = result?.range(at: 1), let range = Range(group, in: htmlData) else {
                    return
                }
                
                let fullAddress = String(htmlData[range])
                var split = fullAddress.components(separatedBy: ":")
                let port = Int32(split.popLast()!)!
                let address = split.joined(separator: ":")
                let addressWithoutPrefix = address.replacingOccurrences(of: "tls://", with: "")
                    .replacingOccurrences(of: "tcp://", with: "")
                                
                NSLog("Connect to \(fullAddress)")
                
                let startTime = DispatchTime.now()
                let client = TCPClient(address: addressWithoutPrefix, port: port)
                switch client.connect(timeout: 1) {
                    case .success:
                        let endTime = DispatchTime.now()
                        let ping = self.CalculateMillisecondsBetween(startTime, endTime)
                        
                        let peer = PeerInfo(address: client.address, port: UInt16(client.port), ping: ping)
                        
                        peers.append(peer)
                        
                        if (ping < 75) {
                            fastPeers += 1
                        }
                    case .failure:
                        NSLog("Ping failed for host \(addressWithoutPrefix)")
                }
                
                if (fastPeers > 2) {
                    stop.pointee = true
                }
            }
            
            peers.sort {
                $0.ping < $1.ping
            }
            
            completionHandler(BestPeersResult.Success(peers: peers))
        } catch let error {
            completionHandler(BestPeersResult.Error(message: error.localizedDescription))
        }
    }
    
    private func CalculateMillisecondsBetween(_ startTime: DispatchTime, _ endTime: DispatchTime) -> UInt64 {
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = nanoTime / 1_000_000
        
        return timeInterval
    }

    
    /*public func socket(_ socket : GCDAsyncSocket, didConnectToHost host:String, port p:UInt16) {
        NSLog("Connected to \(host)")
        
        socket.disconnect()
        
        peers.append(PeerInfo(address: host, port: p))
    }
 */
}
