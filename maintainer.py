#!/usr/bin/python3

# Filename: maintainer.py
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 10/09/2016

# Copyright (C) 2016  Michael Mair-Keimberger
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Discription: simple python script to get all gentoo projects
#               and its members (can be filtered with grep)

projxml = "/usr/portage/metadata/projects.xml"

import xml.etree.ElementTree
e = xml.etree.ElementTree.parse(projxml).getroot()

for i in e:
    for v in i.iter('member'):
        print(i[1].text,'(',i[0].text,')  <<  ',v[1].text,'(',v[0].text,')')
