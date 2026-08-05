import Foundation

/// `Color Adjustments` — Final Cut's current default colour correction, the
/// one `⌘6` offers in place of the retired Color Board.
///
/// Its identity was **not** derivable from `Filters.bundle` by name. Two
/// candidates were read out of that plist beforehand — `PAECorrectorEffect`
/// and the obsolete `PAESaturation` — and the capture matched neither. The uid
/// below is internally `PAEHDRColorCorrect`. This is the second time a Final
/// Cut effect uid has had to come from Final Cut rather than from a plausible
/// reading of its plugin list.
///
/// The three opaque payloads are reproduced byte-for-byte from the capture.
/// They are *not* captured state:
///
/// - `effectConfig` decodes to a 289-byte `NSKeyedArchiver` holding exactly
///   `{"pluginVersion": 3}`.
/// - keys 20 and 23 are base64 `ozml` parameter blocks with
///   `numberOfKeypoints=0` whose `defaultVal` equals their `dataValue` —
///   untouched defaults.
///
/// Whether Final Cut accepts the filter *without* them is an admission
/// question. This emitter carries them because the first probe reproduces the
/// observed construction; dropping them is a later, separate experiment.
public enum NativeFCPXMLColorAdjustments {
    public static let effectName = "Color Adjustments"
    public static let effectUID = "FxPlug:7E2022A5-202B-4EEB-A311-AC2B585D01B0"

    /// Verbatim from the capture. Line breaks are Swift concatenation only.
    enum Blobs {
    static let effectConfig =
        "YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZl" +
        "ctEICVRyb290gAGlCwwVFhdVJG51bGzTDQ4PEBIUV05TLmtleXNaTlMub2JqZWN0c1YkY2xhc3OhEYACoROAA4AEXXBsdWdp" +
        "blZlcnNpb24QA9IYGRobWiRjbGFzc25hbWVYJGNsYXNzZXNfEBNOU011dGFibGVEaWN0aW9uYXJ5oxocHVxOU0RpY3Rpb25h" +
        "cnlYTlNPYmplY3QIERokKTI3SUxRU1lfZm55gIKEhoiKmJqfqrPJzdoAAAAAAAABAQAAAAAAAAAeAAAAAAAAAAAAAAAAAAAA" +
        "4w=="
    static let unnamedChannelKey20 =
        "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NUWVBFIG96eG1sc2NlbmU+Cjxvem1sIHZlcnNp" +
        "b249IjUuMTUiPgoKPGZhY3RvcnkgaWQ9IjEiIHV1aWQ9IjE0NTA0OTJkODU0NTQ5Mzk4YzA3M2MxOGM2NDRhYWUxIj4KCTxk" +
        "ZXNjcmlwdGlvbj5DaGFubmVsPC9kZXNjcmlwdGlvbj4KCTxtYW51ZmFjdHVyZXI+QXBwbGU8L21hbnVmYWN0dXJlcj4KCTx2" +
        "ZXJzaW9uPjE8L3ZlcnNpb24+CjwvZmFjdG9yeT4KCgo8cGFyYW1ldGVyIG5hbWU9IiIgaWQ9IjIwIiBmbGFncz0iNDI5NTAz" +
        "Mjg0OCI+Cgk8ZmxhZ3M+NDI5NTAzMjg0ODwvZmxhZ3M+Cgk8bnVtYmVyT2ZLZXlwb2ludHM+MDwvbnVtYmVyT2ZLZXlwb2lu" +
        "dHM+Cgk8ZGVmYXVsdFZhbD4qKioqKioqKio2SWVNYi1nT0xCb0ExMUkqRTYxLSpJNC1rZE03NU5aUWJCZFBxdE43NDNtTXFW" +
        "ZFJhSm1KMEZvUHItTTc0eFdPYUpYUjVBRyoqNDRjM3dFMW90SEdxSnROS0YtUWFCY09MTlpRaDI2MEo2WUE2KipjRWhKNzR0" +
        "cFA0azYyRmNZOEg2ckdJbERJSkEqKioqKioqKi0qRSoqKioqKioqKkEqKioqKioqKioqKioqKioqKioqKktFKio8L2RlZmF1" +
        "bHRWYWw+Cgk8ZGF0YVZhbHVlPioqKioqKioqKjZJZU1iLWdPTEJvQTExSSpFNjEtKkk0LWtkTTc1TlpRYkJkUHF0Tjc0M21N" +
        "cVZkUmFKbUowRm9Qci1NNzR4V09hSlhSNUFHKio0NGMzd0Uxb3RIR3FKdE5LRi1RYUJjT0xOWlFoMjYwSjZZQTYqKmNFaEo3" +
        "NHRwUDRrNjJGY1k4SDZyR0lsRElKQSoqKioqKioqLSpFKioqKioqKioqQSoqKioqKioqKioqKioqKioqKioqS0UqKjwvZGF0" +
        "YVZhbHVlPgo8L3BhcmFtZXRlcj4KCjwvb3ptbD4K"
    static let neutralizationData =
        "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NUWVBFIG96eG1sc2NlbmU+Cjxvem1sIHZlcnNp" +
        "b249IjUuMTUiPgoKPGZhY3RvcnkgaWQ9IjEiIHV1aWQ9IjRkMGU0OGQ4NGZjYTQyNGQ4MmFhOThhMDI3YzZlYzVjIj4KCTxk" +
        "ZXNjcmlwdGlvbj5DaGFubmVsPC9kZXNjcmlwdGlvbj4KCTxtYW51ZmFjdHVyZXI+QXBwbGU8L21hbnVmYWN0dXJlcj4KCTx2" +
        "ZXJzaW9uPjE8L3ZlcnNpb24+CjwvZmFjdG9yeT4KCgo8cGFyYW1ldGVyIG5hbWU9Ik5ldXRyYWxpemF0aW9uIERhdGEiIGlk" +
        "PSIyMyIgZmxhZ3M9IjQyOTkyMjcxODQiPgoJPGZsYWdzPjQyOTkyMjcxODQ8L2ZsYWdzPgoJPG51bWJlck9mS2V5cG9pbnRz" +
        "PjA8L251bWJlck9mS2V5cG9pbnRzPgoJPGRlZmF1bHRWYWw+KioqKioqKioqU1llTWItZ09MQm9BMTFJKkU2MS0qSTQta2RN" +
        "NzVOWlFiQmRQcXRONzQzbU1xVmRSYUptSjBGb1ByLU03NHhXT2FKWFI1QUcqKjQ0YzN3RTFvdEhHcUp0TktGLVFhQmNPTE5a" +
        "UWgyNjBKNllBNiotY2tnQTVaSVlQYkpnUEJ3RTFrb0MxbCpGMlZBSTNGTUw0LVlPNGxrUTUta1E1LWtSNS1rUTUta1E1M1ZY" +
        "UHF0b1FhM25SM3dFMXJCcFE0Sm1HNFpiTzRsZE5xVm9RcHBuTzQzWVByUm5KcTNtUExGY0thN2dNS0JmSTR4ZFBiRktScTNt" +
        "UExGY0o1RmRQYkZRUEtaWVI0eGlOTEJJT0t0b0pXRlhQNDNuUXBobk80M1lQclJuSjRaaVIzZGNPS1JjUDRaYk81Rm5LYkJW" +
        "UjVKbU1MRmRQcXRPTWI3ZE5xVm9QYUpuUXBWWlM1LWpRckptTkp0aE9LRm9QcXRaUXBSVlFhcG9PM1JuTzQzWVByUm42WWdN" +
        "WmMwKipoNlQ2MDJXS1dGWFA0M25RcXRWUEtKTTc0QmdNTEJuTkxCVDItVkVFSUo2RjM3MVBxbGpRWUJqUWI3Wk1yRktNS2xw" +
        "TkxDVzZtRlQyLVZFRUlKNkYzNzFQcWxqUVlCalFiN1pNckZLTUtscE5MQk1IWkJETWFkWk1yRSowKipGKi1jKjcqKmQqMTYq" +
        "QmstNyoyaypIay1GKjNJKktrLXcqNkkqWmswWio5KipoazB3KkFZKm8qMVEqQ1Eqd1UxeCpFTS0zRTJSKkc2LTcqMmQqSEUt" +
        "REUzTSpKZy1SVSoqKioqKioqNi0qKioqKioqKiowSSoqKioqKioqKioqKioqKioqKiozejwvZGVmYXVsdFZhbD4KCTxkYXRh" +
        "VmFsdWU+KioqKioqKioqU1llTWItZ09MQm9BMTFJKkU2MS0qSTQta2RNNzVOWlFiQmRQcXRONzQzbU1xVmRSYUptSjBGb1By" +
        "LU03NHhXT2FKWFI1QUcqKjQ0YzN3RTFvdEhHcUp0TktGLVFhQmNPTE5aUWgyNjBKNllBNiotY2tnQTVaSVlQYkpnUEJ3RTFr" +
        "b0MxbCpGMlZBSTNGTUw0LVlPNGxrUTUta1E1LWtSNS1rUTUta1E1M1ZYUHF0b1FhM25SM3dFMXJCcFE0Sm1HNFpiTzRsZE5x" +
        "Vm9RcHBuTzQzWVByUm5KcTNtUExGY0thN2dNS0JmSTR4ZFBiRktScTNtUExGY0o1RmRQYkZRUEtaWVI0eGlOTEJJT0t0b0pX" +
        "RlhQNDNuUXBobk80M1lQclJuSjRaaVIzZGNPS1JjUDRaYk81Rm5LYkJWUjVKbU1MRmRQcXRPTWI3ZE5xVm9QYUpuUXBWWlM1" +
        "LWpRckptTkp0aE9LRm9QcXRaUXBSVlFhcG9PM1JuTzQzWVByUm42WWdNWmMwKipoNlQ2MDJXS1dGWFA0M25RcXRWUEtKTTc0" +
        "QmdNTEJuTkxCVDItVkVFSUo2RjM3MVBxbGpRWUJqUWI3Wk1yRktNS2xwTkxDVzZtRlQyLVZFRUlKNkYzNzFQcWxqUVlCalFi" +
        "N1pNckZLTUtscE5MQk1IWkJETWFkWk1yRSowKipGKi1jKjcqKmQqMTYqQmstNyoyaypIay1GKjNJKktrLXcqNkkqWmswWio5" +
        "KipoazB3KkFZKm8qMVEqQ1Eqd1UxeCpFTS0zRTJSKkc2LTcqMmQqSEUtREUzTSpKZy1SVSoqKioqKioqNi0qKioqKioqKiow" +
        "SSoqKioqKioqKioqKioqKioqKiozejwvZGF0YVZhbHVlPgo8L3BhcmFtZXRlcj4KCjwvb3ptbD4K"
    }

    /// Every param Final Cut wrote, in the order it wrote them, at the values
    /// it wrote — except `Saturation`, which the caller supplies.
    static let capturedParameters: [(name: String, key: String, value: String)] = [
        (name: "Control Range", key: "19", value: "0 (SDR)"),
        (name: "", key: "20", value: Blobs.unnamedChannelKey20),
        (name: "Neutralization Data", key: "23", value: Blobs.neutralizationData),
        (name: "trigger Enhance", key: "18", value: "6"),
        (name: "Exposure", key: "3", value: "0"),
        (name: "Contrast", key: "17", value: "0"),
        (name: "Brightness", key: "2", value: "0"),
        (name: "Highlights", key: "7", value: "0"),
        (name: "Black Point", key: "1", value: "0"),
        (name: "Shadows", key: "4", value: "0"),
        (name: "Super Highlights", key: "25", value: "0"),
        (name: "Saturation", key: "16", value: "25"),
        (name: "Highlights Warmth", key: "10", value: "0"),
        (name: "Highlights Tint", key: "11", value: "0"),
        (name: "Midtones Warmth", key: "12", value: "0"),
        (name: "Midtones Tint", key: "13", value: "0"),
        (name: "Shadows Warmth", key: "14", value: "0"),
        (name: "Shadows Tint", key: "15", value: "0"),
    ]

    public static let saturationKey = "16"

    public static func effectNode(id: String) -> NativeFCPXMLNode {
        NativeFCPXMLNode("effect", attributes: [("id", id), ("name", effectName), ("uid", effectUID)])
    }

    /// `<filter-video>` with the captured parameter set, overriding only
    /// `Saturation`.
    ///
    /// `saturation` is passed through unmapped. The composition model stores
    /// `colorEnrichment` on a 0–0.5 scale and this param ran 0–100 in the
    /// inspector, but no observation ties the two together, so inventing a
    /// conversion here would smuggle an unverified assumption into the probe.
    public static func filterNode(ref: String, saturation: Double) -> NativeFCPXMLNode {
        var children: [NativeFCPXMLNode] = [dataNode(key: "effectConfig", value: Blobs.effectConfig)]
        for parameter in capturedParameters {
            let value = parameter.key == saturationKey ? NativeFCPXMLNumber.string(saturation) : parameter.value
            children.append(NativeFCPXMLNode("param", attributes: [
                ("name", parameter.name), ("key", parameter.key), ("value", value)
            ]))
        }
        return NativeFCPXMLNode("filter-video", attributes: [("ref", ref), ("name", effectName)], children: children)
    }

    private static func dataNode(key: String, value: String) -> NativeFCPXMLNode {
        NativeFCPXMLNode.text(name: "data", attributes: [("key", key)], text: value)
    }
}
