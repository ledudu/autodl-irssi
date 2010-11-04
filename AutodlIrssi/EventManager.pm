# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
# The Original Code is IRC Auto Downloader
#
# The Initial Developer of the Original Code is
# David Nilsson.
# Portions created by the Initial Developer are Copyright (C) 2010
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****

#
# Sometimes events aren't sent to all listeners by Irssi, eg. when our code disconnects an IRC
# server. This module fixes that problem.
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi::EventManager;
use AutodlIrssi::Globals;
use AutodlIrssi::Irssi;

sub new {
	my $class = shift;
	bless {
		handlerId => 0,
		events => {},
	}, $class;
}

sub cleanUp {
	my $self = shift;

	for my $eventInfo (values %{$self->{events}}) {
		message 0, "Event '$eventInfo->{event}' was not unregistered";
		irssi_signal_remove($eventInfo->{event}, $eventInfo->{myHandler});
		$eventInfo->{myHandler} = undef;
	}
	$self->{events} = {};
}

sub register {
	my ($self, $event, $handler) = @_;

	my $eventInfo = $self->{events}{$event};
	if (!$eventInfo) {
		$self->{events}{$event} = $eventInfo = {
			event => $event,
			handlers => {},
			myHandler => sub {
				$self->_notifyObservers($eventInfo, @_);
			},
		};
		irssi_signal_add($eventInfo->{event}, $eventInfo->{myHandler});
	}
	my $handlerId = $self->{handlerId}++;
	$eventInfo->{handlers}{$handlerId} = $handler;
	return $handlerId;
}

sub unregister {
	my ($self, $event, $handlerId) = @_;

	my $eventInfo = $self->{events}{$event};
	if (!$eventInfo || !$eventInfo->{handlers}{$handlerId}) {
		message 0, "EventManager: invalid handler id ($handlerId) for event '$event'";
		return;
	}
	delete $eventInfo->{handlers}{$handlerId};
	if (keys(%{$eventInfo->{handlers}}) == 0) {
		irssi_signal_remove($eventInfo->{event}, $eventInfo->{myHandler});
		$eventInfo->{myHandler} = undef;	# Clear circular ref, no mem leaks thanks
		delete $self->{events}{$event};
	}
}

sub _notifyObservers {
	my ($self, $eventInfo, @args) = @_;

	for my $handler (values %{$eventInfo->{handlers}}) {
		eval {
			$handler->(@args);
		};
		if ($@) {
			chomp $@;
			message 0, "EventManger: $eventInfo->{event}: handler error. ex: $@";
		}
	}
}

1;
