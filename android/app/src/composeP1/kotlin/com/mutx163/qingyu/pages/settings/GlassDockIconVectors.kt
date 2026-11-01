package com.mutx163.qingyu.pages.settings

import androidx.compose.ui.graphics.vector.ImageVector
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.AddCircle
import top.yukonga.miuix.kmp.icon.extended.AddFolder
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Album
import top.yukonga.miuix.kmp.icon.extended.All
import top.yukonga.miuix.kmp.icon.extended.Answer
import top.yukonga.miuix.kmp.icon.extended.AppRecording
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Background
import top.yukonga.miuix.kmp.icon.extended.Backup
import top.yukonga.miuix.kmp.icon.extended.BankCards
import top.yukonga.miuix.kmp.icon.extended.Blocklist
import top.yukonga.miuix.kmp.icon.extended.CallRecording
import top.yukonga.miuix.kmp.icon.extended.Carrier
import top.yukonga.miuix.kmp.icon.extended.ChevronBackward
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Clear
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.icon.extended.Close2
import top.yukonga.miuix.kmp.icon.extended.CloudFill
import top.yukonga.miuix.kmp.icon.extended.Community
import top.yukonga.miuix.kmp.icon.extended.Contacts
import top.yukonga.miuix.kmp.icon.extended.ContactsBook
import top.yukonga.miuix.kmp.icon.extended.ContactsCircle
import top.yukonga.miuix.kmp.icon.extended.ConvertFile
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.icon.extended.Create
import top.yukonga.miuix.kmp.icon.extended.Cut
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Download
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.Email
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.FavoritesFill
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.FileDownloads
import top.yukonga.miuix.kmp.icon.extended.Filter
import top.yukonga.miuix.kmp.icon.extended.Folder
import top.yukonga.miuix.kmp.icon.extended.FolderFill
import top.yukonga.miuix.kmp.icon.extended.Forward
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Help
import top.yukonga.miuix.kmp.icon.extended.Hide
import top.yukonga.miuix.kmp.icon.extended.Home
import top.yukonga.miuix.kmp.icon.extended.HorizontalSplit
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Layers
import top.yukonga.miuix.kmp.icon.extended.Link
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Lock
import top.yukonga.miuix.kmp.icon.extended.MapAlbum
import top.yukonga.miuix.kmp.icon.extended.Merge
import top.yukonga.miuix.kmp.icon.extended.Messages
import top.yukonga.miuix.kmp.icon.extended.Mic
import top.yukonga.miuix.kmp.icon.extended.MicSlash
import top.yukonga.miuix.kmp.icon.extended.MindMap
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.MoreCircle
import top.yukonga.miuix.kmp.icon.extended.MoveFile
import top.yukonga.miuix.kmp.icon.extended.Music
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.NotesFill
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Paste
import top.yukonga.miuix.kmp.icon.extended.Pause
import top.yukonga.miuix.kmp.icon.extended.Phone
import top.yukonga.miuix.kmp.icon.extended.Photos
import top.yukonga.miuix.kmp.icon.extended.Pin
import top.yukonga.miuix.kmp.icon.extended.Play
import top.yukonga.miuix.kmp.icon.extended.Playlist
import top.yukonga.miuix.kmp.icon.extended.Promotions
import top.yukonga.miuix.kmp.icon.extended.Recent
import top.yukonga.miuix.kmp.icon.extended.Recording
import top.yukonga.miuix.kmp.icon.extended.RecordingTape
import top.yukonga.miuix.kmp.icon.extended.Redo
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.icon.extended.RemoveContact
import top.yukonga.miuix.kmp.icon.extended.Rename
import top.yukonga.miuix.kmp.icon.extended.Replace
import top.yukonga.miuix.kmp.icon.extended.Reply
import top.yukonga.miuix.kmp.icon.extended.ReplyAll
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Reset
import top.yukonga.miuix.kmp.icon.extended.RotateLeft
import top.yukonga.miuix.kmp.icon.extended.Scan
import top.yukonga.miuix.kmp.icon.extended.ScreenCapture
import top.yukonga.miuix.kmp.icon.extended.ScreenMirroring
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.icon.extended.SearchDevice
import top.yukonga.miuix.kmp.icon.extended.SelectAll
import top.yukonga.miuix.kmp.icon.extended.Send
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.icon.extended.Show
import top.yukonga.miuix.kmp.icon.extended.Sidebar
import top.yukonga.miuix.kmp.icon.extended.Sort
import top.yukonga.miuix.kmp.icon.extended.Stopwatch
import top.yukonga.miuix.kmp.icon.extended.Store
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.icon.extended.Th1
import top.yukonga.miuix.kmp.icon.extended.Th10
import top.yukonga.miuix.kmp.icon.extended.Th11
import top.yukonga.miuix.kmp.icon.extended.Th12
import top.yukonga.miuix.kmp.icon.extended.Th13
import top.yukonga.miuix.kmp.icon.extended.Th14
import top.yukonga.miuix.kmp.icon.extended.Th15
import top.yukonga.miuix.kmp.icon.extended.Th16
import top.yukonga.miuix.kmp.icon.extended.Th17
import top.yukonga.miuix.kmp.icon.extended.Th18
import top.yukonga.miuix.kmp.icon.extended.Th19
import top.yukonga.miuix.kmp.icon.extended.Th2
import top.yukonga.miuix.kmp.icon.extended.Th20
import top.yukonga.miuix.kmp.icon.extended.Th21
import top.yukonga.miuix.kmp.icon.extended.Th22
import top.yukonga.miuix.kmp.icon.extended.Th23
import top.yukonga.miuix.kmp.icon.extended.Th24
import top.yukonga.miuix.kmp.icon.extended.Th25
import top.yukonga.miuix.kmp.icon.extended.Th26
import top.yukonga.miuix.kmp.icon.extended.Th27
import top.yukonga.miuix.kmp.icon.extended.Th28
import top.yukonga.miuix.kmp.icon.extended.Th29
import top.yukonga.miuix.kmp.icon.extended.Th3
import top.yukonga.miuix.kmp.icon.extended.Th30
import top.yukonga.miuix.kmp.icon.extended.Th31
import top.yukonga.miuix.kmp.icon.extended.Th4
import top.yukonga.miuix.kmp.icon.extended.Th5
import top.yukonga.miuix.kmp.icon.extended.Th6
import top.yukonga.miuix.kmp.icon.extended.Th7
import top.yukonga.miuix.kmp.icon.extended.Th8
import top.yukonga.miuix.kmp.icon.extended.Th9
import top.yukonga.miuix.kmp.icon.extended.Theme
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.icon.extended.TopDownloads
import top.yukonga.miuix.kmp.icon.extended.Translate
import top.yukonga.miuix.kmp.icon.extended.Trim
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.icon.extended.Undo
import top.yukonga.miuix.kmp.icon.extended.Unlock
import top.yukonga.miuix.kmp.icon.extended.Unpin
import top.yukonga.miuix.kmp.icon.extended.Update
import top.yukonga.miuix.kmp.icon.extended.UploadCloud
import top.yukonga.miuix.kmp.icon.extended.VerticalSplit
import top.yukonga.miuix.kmp.icon.extended.VolumeOff
import top.yukonga.miuix.kmp.icon.extended.VolumeUp
import top.yukonga.miuix.kmp.icon.extended.Weeks
import top.yukonga.miuix.kmp.icon.extended.WorldClock
import top.yukonga.miuix.kmp.icon.extended.Years
import top.yukonga.miuix.kmp.icon.extended.ZoomOut

/**
 * 圆钮图标挑选页的「图标名 → 矢量」表。
 *
 * 键表与 [GlassDockIconCatalog.names] 同源：Dart `MiuixIcons.extended.names` /
 * `miuix-icons-android:0.9.4` 的 `extended` 包逐项对应（小驼峰 → 首字母大写）。
 * 为什么不能像 Dart 那样在运行时枚举：Kotlin 侧每个图标是 `MiuixIcons` 的**扩展属性**，
 * AAR 里没有名字注册表，只能在这里建一张显式表。
 *
 * `main` 源集不能依赖 Miuix，所以本文件放在 `composeP1`；页面模型只吃
 * [IconPickerState.names]（来自 [GlassDockIconCatalog]）。
 */
object GlassDockIconVectors {

    /** 名字 → 矢量图标；未知名字返回 null（Dart `byName` 同语义，格子回退加号）。 */
    fun byName(name: String): ImageVector? = ICONS[name]

    private val ICONS: Map<String, ImageVector> = linkedMapOf(
        "add" to MiuixIcons.Add,
        "addCircle" to MiuixIcons.AddCircle,
        "addFolder" to MiuixIcons.AddFolder,
        "alarm" to MiuixIcons.Alarm,
        "album" to MiuixIcons.Album,
        "all" to MiuixIcons.All,
        "answer" to MiuixIcons.Answer,
        "appRecording" to MiuixIcons.AppRecording,
        "back" to MiuixIcons.Back,
        "background" to MiuixIcons.Background,
        "backup" to MiuixIcons.Backup,
        "bankCards" to MiuixIcons.BankCards,
        "blocklist" to MiuixIcons.Blocklist,
        "callRecording" to MiuixIcons.CallRecording,
        "carrier" to MiuixIcons.Carrier,
        "chevronBackward" to MiuixIcons.ChevronBackward,
        "chevronForward" to MiuixIcons.ChevronForward,
        "clear" to MiuixIcons.Clear,
        "close" to MiuixIcons.Close,
        "close2" to MiuixIcons.Close2,
        "cloudFill" to MiuixIcons.CloudFill,
        "community" to MiuixIcons.Community,
        "contacts" to MiuixIcons.Contacts,
        "contactsBook" to MiuixIcons.ContactsBook,
        "contactsCircle" to MiuixIcons.ContactsCircle,
        "convertFile" to MiuixIcons.ConvertFile,
        "copy" to MiuixIcons.Copy,
        "create" to MiuixIcons.Create,
        "cut" to MiuixIcons.Cut,
        "delete" to MiuixIcons.Delete,
        "download" to MiuixIcons.Download,
        "edit" to MiuixIcons.Edit,
        "email" to MiuixIcons.Email,
        "expandLess" to MiuixIcons.ExpandLess,
        "expandMore" to MiuixIcons.ExpandMore,
        "favorites" to MiuixIcons.Favorites,
        "favoritesFill" to MiuixIcons.FavoritesFill,
        "file" to MiuixIcons.File,
        "fileDownloads" to MiuixIcons.FileDownloads,
        "filter" to MiuixIcons.Filter,
        "folder" to MiuixIcons.Folder,
        "folderFill" to MiuixIcons.FolderFill,
        "forward" to MiuixIcons.Forward,
        "gridView" to MiuixIcons.GridView,
        "help" to MiuixIcons.Help,
        "hide" to MiuixIcons.Hide,
        "home" to MiuixIcons.Home,
        "horizontalSplit" to MiuixIcons.HorizontalSplit,
        "image" to MiuixIcons.Image,
        "import" to MiuixIcons.Import,
        "info" to MiuixIcons.Info,
        "layers" to MiuixIcons.Layers,
        "link" to MiuixIcons.Link,
        "listView" to MiuixIcons.ListView,
        "location" to MiuixIcons.Location,
        "lock" to MiuixIcons.Lock,
        "mapAlbum" to MiuixIcons.MapAlbum,
        "merge" to MiuixIcons.Merge,
        "messages" to MiuixIcons.Messages,
        "mic" to MiuixIcons.Mic,
        "micSlash" to MiuixIcons.MicSlash,
        "mindMap" to MiuixIcons.MindMap,
        "months" to MiuixIcons.Months,
        "more" to MiuixIcons.More,
        "moreCircle" to MiuixIcons.MoreCircle,
        "moveFile" to MiuixIcons.MoveFile,
        "music" to MiuixIcons.Music,
        "notes" to MiuixIcons.Notes,
        "notesFill" to MiuixIcons.NotesFill,
        "ok" to MiuixIcons.Ok,
        "paste" to MiuixIcons.Paste,
        "pause" to MiuixIcons.Pause,
        "phone" to MiuixIcons.Phone,
        "photos" to MiuixIcons.Photos,
        "pin" to MiuixIcons.Pin,
        "play" to MiuixIcons.Play,
        "playlist" to MiuixIcons.Playlist,
        "promotions" to MiuixIcons.Promotions,
        "recent" to MiuixIcons.Recent,
        "recording" to MiuixIcons.Recording,
        "recordingTape" to MiuixIcons.RecordingTape,
        "redo" to MiuixIcons.Redo,
        "refresh" to MiuixIcons.Refresh,
        "remove" to MiuixIcons.Remove,
        "removeContact" to MiuixIcons.RemoveContact,
        "rename" to MiuixIcons.Rename,
        "replace" to MiuixIcons.Replace,
        "reply" to MiuixIcons.Reply,
        "replyAll" to MiuixIcons.ReplyAll,
        "report" to MiuixIcons.Report,
        "reset" to MiuixIcons.Reset,
        "rotateLeft" to MiuixIcons.RotateLeft,
        "scan" to MiuixIcons.Scan,
        "screenCapture" to MiuixIcons.ScreenCapture,
        "screenMirroring" to MiuixIcons.ScreenMirroring,
        "search" to MiuixIcons.Search,
        "searchDevice" to MiuixIcons.SearchDevice,
        "selectAll" to MiuixIcons.SelectAll,
        "send" to MiuixIcons.Send,
        "settings" to MiuixIcons.Settings,
        "share" to MiuixIcons.Share,
        "show" to MiuixIcons.Show,
        "sidebar" to MiuixIcons.Sidebar,
        "sort" to MiuixIcons.Sort,
        "stopwatch" to MiuixIcons.Stopwatch,
        "store" to MiuixIcons.Store,
        "tasks" to MiuixIcons.Tasks,
        "th1" to MiuixIcons.Th1,
        "th10" to MiuixIcons.Th10,
        "th11" to MiuixIcons.Th11,
        "th12" to MiuixIcons.Th12,
        "th13" to MiuixIcons.Th13,
        "th14" to MiuixIcons.Th14,
        "th15" to MiuixIcons.Th15,
        "th16" to MiuixIcons.Th16,
        "th17" to MiuixIcons.Th17,
        "th18" to MiuixIcons.Th18,
        "th19" to MiuixIcons.Th19,
        "th2" to MiuixIcons.Th2,
        "th20" to MiuixIcons.Th20,
        "th21" to MiuixIcons.Th21,
        "th22" to MiuixIcons.Th22,
        "th23" to MiuixIcons.Th23,
        "th24" to MiuixIcons.Th24,
        "th25" to MiuixIcons.Th25,
        "th26" to MiuixIcons.Th26,
        "th27" to MiuixIcons.Th27,
        "th28" to MiuixIcons.Th28,
        "th29" to MiuixIcons.Th29,
        "th3" to MiuixIcons.Th3,
        "th30" to MiuixIcons.Th30,
        "th31" to MiuixIcons.Th31,
        "th4" to MiuixIcons.Th4,
        "th5" to MiuixIcons.Th5,
        "th6" to MiuixIcons.Th6,
        "th7" to MiuixIcons.Th7,
        "th8" to MiuixIcons.Th8,
        "th9" to MiuixIcons.Th9,
        "theme" to MiuixIcons.Theme,
        "timer" to MiuixIcons.Timer,
        "topDownloads" to MiuixIcons.TopDownloads,
        "translate" to MiuixIcons.Translate,
        "trim" to MiuixIcons.Trim,
        "tune" to MiuixIcons.Tune,
        "undo" to MiuixIcons.Undo,
        "unlock" to MiuixIcons.Unlock,
        "unpin" to MiuixIcons.Unpin,
        "update" to MiuixIcons.Update,
        "uploadCloud" to MiuixIcons.UploadCloud,
        "verticalSplit" to MiuixIcons.VerticalSplit,
        "volumeOff" to MiuixIcons.VolumeOff,
        "volumeUp" to MiuixIcons.VolumeUp,
        "weeks" to MiuixIcons.Weeks,
        "worldClock" to MiuixIcons.WorldClock,
        "years" to MiuixIcons.Years,
        "zoomOut" to MiuixIcons.ZoomOut,
    )
}
