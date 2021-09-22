locals {
   dir = "${path.cwd}/src/"
   mime_types = {
      htm = "text/html"
      html = "text/html"
      css = "text/css"
      ttf = "font/tff"
      js = "application/javascript"
      map = "application/javascript"
      json = "application/json"
      gif = "image/gif"
      jpeg = "image/jpeg"
      png = "image/png"
      svg = "image/svg"
      jpg = "image/jpg"
      woff = "font/woff"
      woff2 = "font/woff2"
      eot = "font/eot"
      otf = "font/otf"
   }
}

variable "www_domain_name" {
   default = "www.cloupros.ml"
}

variable "root_domain_name"{
   default = "cloudpros.ml"
}