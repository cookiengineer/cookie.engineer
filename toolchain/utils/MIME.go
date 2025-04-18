package utils

var MIME map[string]string = map[string]string{

	"webmanifest": "application/manifest+json",

	// application
	"abw":   "application/x-abiword",
	"azw":   "application/vnd.amazon.ebook",
	"bin":   "application/octet-stream",
	"csh":   "application/x-csh",
	"doc":   "application/msword",
	"docx":  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
	"eot":   "application/vnd.ms-fontobject",
	"js":    "application/javascript",
	"json":  "application/json",
	"mjs":   "application/javascript",
	"odp":   "application/vnd.oasis.opendocument.presentation",
	"ods":   "application/vnd.oasis.opendocument.spreadsheet",
	"odt":   "application/vnd.oasis.opendocument.text",
	"ogx":   "application/ogg",
	"pdf":   "application/pdf",
	"ppt":   "application/vnd.ms-powerpoint",
	"pptx":  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
	"rtf":   "application/rtf",
	"sh":    "application/x-sh",
	"ts":    "application/typescript",
	"vsd":   "application/vnd.visio",
	"xhtml": "application/xhtml+xml",
	"xls":   "application/vnd.ms-excel",
	"xlsx":  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
	"xml":   "application/xml",
	"xul":   "application/vnd.mozilla.xul+xml",

	// audio
	"3gp":  "audio/3gpp",
	"3gpp": "audio/3gpp",
	"aac":  "audio/aac",
	"ac3":  "audio/ac3",
	"mid":  "audio/midi",
	"mp3":  "audio/mp3",
	"oga":  "audio/ogg",
	"ogg":  "audio/ogg",
	"wav":  "audio/wav",
	"weba": "audio/webm",

	// font
	"otf":   "font/otf",
	"sfnt":  "font/sfnt",
	"ttf":   "font/ttf",
	"woff":  "font/woff",
	"woff2": "font/woff2",

	// image
	"bmp":  "image/bmp",
	"emf":  "image/emf",
	"gif":  "image/gif",
	"ico":  "image/x-icon",
	"jp2":  "image/jp2",
	"jpeg": "image/jpeg",
	"jpg":  "image/jpeg",
	"png":  "image/png",
	"tif":  "image/tiff",
	"tiff": "image/tiff",
	"svg":  "image/svg+xml",
	"webp": "image/webp",
	"wmf":  "image/wmf",

	// text
	"appcache": "text/cache-manifest",
	"css":      "text/css",
	"csv":      "text/csv",
	"htm":      "text/html",
	"html":     "text/html",
	"ical":     "text/calendar",
	"md":       "text/x-markdown",
	"mf":       "text/cache-manifest",
	"txt":      "text/plain",

	// video
	"avi":  "video/x-msvideo",
	"m4v":  "video/mp4",
	"mov":  "video/quicktime",
	"mp4":  "video/mp4",
	"mpeg": "video/mpeg",
	"mpg4": "video/mp4",
	"ogv":  "video/ogg",
	"qt":   "video/quicktime",
	"webm": "video/webm",

	// other
	"7z":   "application/x-7z-compressed",
	"bz":   "application/x-bzip",
	"bz2":  "application/x-bzip2",
	"epub": "application/epub+zip",
	"gz":   "application/x-gzip",
	"jar":  "application/jar-archive",
	"pac":  "application/x-ns-proxy-autoconfig",
	"rar":  "application/x-rar-compressed",
	"tar":  "application/x-tar",
	"zip":  "application/zip",
}
