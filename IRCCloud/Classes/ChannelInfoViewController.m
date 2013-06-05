//
//  ChannelInfoViewController.m
//  IRCCloud
//
//  Created by Sam Steele on 6/4/13.
//  Copyright (c) 2013 IRCCloud, Ltd. All rights reserved.
//

#import "ChannelInfoViewController.h"
#import "ColorFormatter.h"
#import "NetworkConnection.h"

@implementation ChannelInfoViewController

-(id)initWithBid:(int)bid {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _channel = [[ChannelsDataSource sharedInstance] channelForBuffer:bid];
        _modeHints = [[NSMutableArray alloc] init];
        _topicChanged = NO;
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.navigationItem.title = @"Info";
        offset = 40;
    } else {
        self.navigationItem.title = [NSString stringWithFormat:@"%@ Info", _channel.name];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
        offset = 80;
    }
    _topicLabel = [[TTTAttributedLabel alloc] initWithFrame:CGRectZero];
    _topicLabel.numberOfLines = 0;
    _topicLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _topicLabel.dataDetectorTypes = UIDataDetectorTypeLink;
    _topicLabel.delegate = self;
    _topicLabel.backgroundColor = [UIColor clearColor];
    _topicEdit = [[UITextView alloc] initWithFrame:CGRectZero];
    _topicEdit.font = [UIFont systemFontOfSize:14];
    _topicEdit.returnKeyType = UIReturnKeyDone;
    _topicEdit.delegate = self;
    _topicEdit.backgroundColor = [UIColor clearColor];
    _openInChromeController = [[OpenInChromeController alloc] init];
    [self refresh];
}

-(void)cancelButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)attributedLabel:(TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    //TODO: check for irc:// URLs
    if(![_openInChromeController openInChrome:url
                              withCallbackURL:[NSURL URLWithString:@"irccloud://"]
                                 createNewTab:NO])
        [[UIApplication sharedApplication] openURL:url];
}

-(void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEvent:) name:kIRCCloudEventNotification object:nil];
}

-(void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)handleEvent:(NSNotification *)notification {
    kIRCEvent event = [[notification.userInfo objectForKey:kIRCCloudEventKey] intValue];
    IRCCloudJSONObject *o = nil;
    
    switch(event) {
        case kIRCEventChannelInit:
        case kIRCEventChannelTopic:
        case kIRCEventChannelMode:
            o = notification.object;
            if(o.bid == _channel.bid && !self.tableView.editing)
                [self refresh];
            break;
        default:
            break;
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    if([text isEqualToString:@"\n"]) {
        [self setEditing:NO animated:YES];
        return NO;
    }
    _topicChanged = YES;
    return YES;
}

-(void)refresh {
    [_modeHints removeAllObjects];
    _topicChanged = NO;
    if([_channel.topic_text isKindOfClass:[NSString class]] && _channel.topic_text.length) {
        _topic = [ColorFormatter format:_channel.topic_text defaultColor:[UIColor blackColor] mono:NO linkify:YES];
        _topicLabel.text = _topic;
        _topicEdit.text = [_topic string];
    } else {
        _topic = [ColorFormatter format:@"(No topic set)" defaultColor:[UIColor grayColor] mono:NO linkify:NO];
        _topicLabel.text = _topic;
        _topicEdit.text = @"";
    }
    if(_channel.mode.length) {
        NSString *mode = _channel.mode;
        NSString *key = nil;
        NSUInteger keypos = [mode rangeOfString:@" "].location;
        if(keypos != NSNotFound) {
            key = [_channel.mode substringFromIndex:keypos + 1];
            mode = [_channel.mode substringToIndex:keypos];
        }
        
        for(int i = 0; i < mode.length; i++) {
            unichar m = [mode characterAtIndex:i];
            switch(m) {
                case 'i':
                    [_modeHints addObject:@{@"mode":@"Invite Only (+i)", @"hint":@"Members must be invited to join this channel."}];
                    break;
                case 'k':
                    [_modeHints addObject:@{@"mode":@"Password (+k)", @"hint":key}];
                    break;
                case 'm':
                    [_modeHints addObject:@{@"mode":@"Moderated (+m)", @"hint":@"Only ops and voiced members may talk."}];
                    break;
                case 'n':
                    [_modeHints addObject:@{@"mode":@"No External Messages (+n)", @"hint":@"No messages allowed from outside the channel."}];
                    break;
                case 'p':
                    [_modeHints addObject:@{@"mode":@"Private (+p)", @"hint":@"Membership is only visible to other members."}];
                    break;
                case 's':
                    [_modeHints addObject:@{@"mode":@"Secret (+s)", @"hint":@"This channel is unlisted and membership is only visible to other members."}];
                    break;
                case 't':
                    [_modeHints addObject:@{@"mode":@"Topic Control (+t)", @"hint":@"Only ops can set the topic."}];
                    break;
            }
        }
    }
    [self.tableView reloadData];
}

-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Table view data source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if([_channel.mode isKindOfClass:[NSString class]] && _channel.mode.length)
        return 2;
    else
        return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch(section) {
        case 1:
            if(_modeHints.count)
                return _modeHints.count;
        default:
            return 1;
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    if(self.tableView.editing && !editing && _topicChanged) {
        [[NetworkConnection sharedInstance] topic:_topicEdit.text chan:_channel.name cid:_channel.cid];
    }
    [super setEditing:editing animated:animated];
    [self.tableView reloadData];
    if(editing)
        [_topicEdit becomeFirstResponder];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        if(tableView.isEditing)
            return 148;
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_topic);
        CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0,0), NULL, CGSizeMake(self.tableView.bounds.size.width - offset,CGFLOAT_MAX), NULL);
        float height = ceilf(suggestedSize.height);
        _topicLabel.frame = CGRectMake(8,8,suggestedSize.width,suggestedSize.height);
        _topicEdit.frame = CGRectMake(4,4,self.tableView.bounds.size.width - offset,140);
        CFRelease(framesetter);
        return height + 20;
    } else {
        if(indexPath.row == 0 && _modeHints.count == 0) {
            return 48;
        } else {
            NSString *hint = [[_modeHints objectAtIndex:indexPath.row] objectForKey:@"hint"];
            return [hint sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(self.tableView.bounds.size.width - offset,CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height + 32;
        }
    }
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch(section) {
        case 0:
            return @"Topic";
        case 1:
            if(_modeHints.count)
                return [NSString stringWithFormat:@"Mode: +%@", _channel.mode];
            else
                return @"Mode";
    }
    return nil;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"infocell"];
    if(!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"infocell"];
    
    switch(indexPath.section) {
        case 0:
            if(tableView.isEditing) {
                [_topicLabel removeFromSuperview];
                [cell.contentView addSubview:_topicEdit];
            } else {
                [_topicEdit removeFromSuperview];
                [cell.contentView addSubview:_topicLabel];
            }
            break;
        case 1:
            if(_modeHints.count) {
                cell.textLabel.text = [[_modeHints objectAtIndex:indexPath.row] objectForKey:@"mode"];
                cell.detailTextLabel.text = [[_modeHints objectAtIndex:indexPath.row] objectForKey:@"hint"];
                cell.detailTextLabel.numberOfLines = 0;
            } else {
                cell.textLabel.text = [NSString stringWithFormat:@"+%@", _channel.mode];
            }
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

@end
