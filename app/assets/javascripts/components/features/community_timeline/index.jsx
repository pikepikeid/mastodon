import { connect } from 'react-redux';
import PureRenderMixin from 'react-addons-pure-render-mixin';
import StatusListContainer from '../ui/containers/status_list_container';
import Column from '../ui/components/column';
import {
  refreshTimeline,
  updateTimeline,
  deleteFromTimelines,
  connectTimeline,
  disconnectTimeline
} from '../../actions/timelines';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import ColumnBackButtonSlim from '../../components/column_back_button_slim';
import createStream from '../../stream';

const messages = defineMessages({
  title: { id: 'column.community', defaultMessage: 'Local timeline' }
});

const mapStateToProps = state => ({
  hasUnread: state.getIn(['timelines', 'community', 'unread']) > 0,
  streamingAPIBaseURL: state.getIn(['meta', 'streaming_api_base_url']),
  accessToken: state.getIn(['meta', 'access_token'])
});

let subscription;

const CommunityTimeline = React.createClass({

  propTypes: {
    dispatch: React.PropTypes.func.isRequired,
    intl: React.PropTypes.object.isRequired,
    streamingAPIBaseURL: React.PropTypes.string,
    accessToken: React.PropTypes.string,
    hasUnread: React.PropTypes.bool,
    standalone: React.PropTypes.bool,
  },

  mixins: [PureRenderMixin],

  getDefaultProps () {
    return {
      standalone: false
    };
  },

  componentDidMount () {
    const { dispatch, streamingAPIBaseURL, accessToken, standalone } = this.props;

    dispatch(refreshTimeline('community'));

    if (typeof subscription !== 'undefined') {
      return;
    }

    if (!standalone) {
      subscription = createStream(streamingAPIBaseURL, accessToken, 'public:local', {

        connected () {
          dispatch(connectTimeline('community'));
        },

        reconnected () {
          dispatch(connectTimeline('community'));
        },

        disconnected () {
          dispatch(disconnectTimeline('community'));
        },

        received (data) {
          switch(data.event) {
          case 'update':
            dispatch(updateTimeline('community', JSON.parse(data.payload)));
            break;
          case 'delete':
            dispatch(deleteFromTimelines(data.payload));
            break;
          }
        }
      });
    } else {
      this.interval = setInterval(() => {
        dispatch(refreshTimeline('community'));
      }, 6000);
    }
  },

  componentWillUnmount () {
    // if (typeof subscription !== 'undefined') {
    //   subscription.close();
    //   subscription = null;
    // }
    clearInterval(this.interval);
  },

  render () {
    let heading;
    const { intl, hasUnread, standalone } = this.props;

    if (standalone) {
      heading = (
        <div style={{ display: 'inline-block', verticalAlign: 'top' }}>
          <div>Pawooのローカルタイムライン</div>
          <div style={{ fontSize: '12px' }}>投稿をリアルタイムに流しています</div>
        </div>
      );
    } else {
      heading = intl.formatMessage(messages.title);
    }

    return (
      <Column icon='users' active={hasUnread} heading={heading}>
        {!standalone && <ColumnBackButtonSlim />}
        <StatusListContainer type='community' standalone={standalone} emptyMessage={<FormattedMessage id='empty_column.community' defaultMessage='The local timeline is empty. Write something publicly to get the ball rolling!' />} />
      </Column>
    );
  },

});

export default connect(mapStateToProps)(injectIntl(CommunityTimeline));
