ActiveMailbox
=============

<http://www.github.com/ipoerner/active_mailbox/>

Ingmar Poerner - maintainer


Description
-----------

ActiveMailbox aims to provide easy, object-oriented access to IMAP mailboxes
from within Ruby applications.

It's a project I've started a couple of years ago, and unfortunately I've
abandoned it since then. Now it doesn't seem to work with any Ruby version that
I tried. Uploading this to Github is a first step in sorting out these issues
and taking up from where I left back then.

It's not usable in its current form, and even when I get it back working there
will still remain a couple of issues until somebody can seriously consider
using it.

Well then, godspeed to myself :-)


Documentation
-------------

The place you will want to look first is the ActiveMailbox::Base class.


Features/Problems
-----------------

This is still a development version. There's plenty of problems.


Synopsis
--------

Quick example of usage, i.e.

```ruby
require 'active_mailbox'

class MyClass < ActiveMailbox::Base
  folder_class :default
  message_class :default
  authenticate_through MyAuthenticatorClass
end

...

MyClass.establish_connection(connection_id)

...

folder = MyClass::ImapMessage.find(connection_id, folder_id)
message = MyClass::ImapMessage.find(connection_id, folder.path, message_id)

...

MyClass.disconnect!(connection_id)
```


Contributing
------------

Just contact me via Github or ipoerner<at>gmail<dot>com


Requirements
------------

* Ruby 1.8
* RMail/TMail libraries
* OpenSSL library


Installation
------------

No way to install so far. Fixing critical bugs is a priority for me right now.


License
-------

Copyright (c) 2011 Ingmar Poerner

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
